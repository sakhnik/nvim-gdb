"""
Run a CLI application in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import argparse
import array
import errno
import fcntl
import os
import pty
import select
import signal
import socket
import termios
import tty

import StreamFilter


class BaseProxy(object):
    """This class does the actual work of the pseudo terminal."""

    def __init__(self, app_name):
        """Create a spawned process."""

        parser = argparse.ArgumentParser(
                description="Run %s through a filtering proxy."
                % app_name)
        parser.add_argument('cmd', metavar='ARGS', nargs='+',
                            help='%s command with arguments'
                            % app_name)
        parser.add_argument('-a', '--address', metavar='ADDR',
                            help='Local socket to receive commands.')
        args = parser.parse_args()

        self.server_address = args.address
        self.argv = args.cmd
        self.logfile = None
        #self.logfile = open("/tmp/log.txt", "w")

        if self.server_address:
            # Create a UDS socket
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
            self.sock.bind(self.server_address)
            self.sock.settimeout(0.5)
        else:
            self.sock = None

        # Create the filter
        self.filter = [(StreamFilter.Filter(), None)]

    def log(self, msg):
        try:
            if not self.logfile is None:
                self.logfile.write(msg)
                self.logfile.write("\n")
                self.logfile.flush()
        except Exception as e:
            print(e)
            raise

    def run(self):
        pid, self.master_fd = pty.fork()
        if pid == pty.CHILD:
            os.execlp(self.argv[0], *self.argv)

        old_handler = signal.signal(signal.SIGWINCH,
                                    lambda signum, frame: self._set_pty_size())

        mode = tty.tcgetattr(pty.STDIN_FILENO)
        tty.setraw(pty.STDIN_FILENO)

        self._set_pty_size()

        try:
            self._process()
        except Exception:
            pass

        tty.tcsetattr(pty.STDIN_FILENO, tty.TCSAFLUSH, mode)

        os.close(self.master_fd)
        self.master_fd = None
        signal.signal(signal.SIGWINCH, old_handler)

        if self.server_address:
            # Make sure the socket does not already exist
            try:
                os.unlink(self.server_address)
            except OSError:
                pass

    def set_filter(self, filter, handler):
        self.log("set_filter %s %s" % (str(filter), str(handler)))
        if len(self.filter) == 1:
            self.log("filter accepted")
            # Only one command at a time. Should be an assertion here,
            # but we wouldn't want to terminate the program.
            if self.filter:
                self._timeout()
            self.filter.append((filter, handler))
            return True
        else:
            self.log("filter rejected")
            return False

    def _set_pty_size(self):
        """Set the window size of the child pty."""
        assert self.master_fd is not None

        buf = array.array('h', [0, 0, 0, 0])
        fcntl.ioctl(pty.STDOUT_FILENO, termios.TIOCGWINSZ, buf, True)
        fcntl.ioctl(self.master_fd, termios.TIOCSWINSZ, buf)

    def _process(self):
        """Run the main loop."""

        while True:
            try:
                sockets = [self.master_fd]
                if self.sock:
                    sockets.append(self.sock)
                # Don't handle user input while a side command is running.
                if len(self.filter) == 1:
                    sockets.append(pty.STDIN_FILENO)
                rfds, wfds, xfds = select.select(sockets, [], [], 0.25)
            except select.error as e:
                if e[0] == errno.EAGAIN:   # Interrupted system call.
                    continue
                else:
                    raise

            if not rfds:
                self._timeout()
            else:
                # Handle one packet at a time to mitigate the side channel
                # breaking into user input.
                if self.master_fd in rfds:
                    data = os.read(self.master_fd, 1024)
                    self.master_read(data)
                elif pty.STDIN_FILENO in rfds:
                    data = os.read(pty.STDIN_FILENO, 1024)
                    self.stdin_read(data)
                elif self.sock in rfds:
                    data, self.last_addr = self.sock.recvfrom(65536)
                    if data[-1] == b'\n':
                        self.log("WARNING: the command ending with <nl>. The StreamProxy filter known to fail.")
                    try:
                        self.log("Got command '%s'" % data.decode('utf-8'))
                        command = self.FilterCommand(data)
                        self.log("Translated command '%s'" % command.decode('utf-8'))
                    except Exception as e:
                        self.log("Exception %s" % str(e))
                        raise
                    if command:
                        self.write_master(command)
                        self.write_master(b'\n')

    def _write(self, fd, data):
        """Write the data to the file."""
        while data:
            n = os.write(fd, data)
            data = data[n:]

    def _timeout(self):
        filter, _ = self.filter[-1]
        data = filter.Timeout()
        self._write(pty.STDOUT_FILENO, data)

    def write_stdout(self, data):
        """Write to stdout for the child process."""
        filter, handler = self.filter[-1]
        data, filtered = filter.Filter(data)
        self._write(pty.STDOUT_FILENO, data)
        if filtered:
            self.log("Filter matched %d bytes" % len(filtered))
            try:
                self.filter.pop()
                res = handler(filtered)
                if res:
                    self.sock.sendto(res, 0, self.last_addr)
            except Exception as e:
                self.log("Exception: %s" % str(e))
                raise

    def write_master(self, data):
        """Write to the child process from its controlling terminal."""
        self._write(self.master_fd, data)

    def master_read(self, data):
        """Handle data from the child process."""
        self.write_stdout(data)

    def stdin_read(self, data):
        """Handle data from the controlling terminal."""
        self.write_master(data)
