"""
Run a CLI application in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import abc
import argparse
import array
import errno
import fcntl
import logging
import os
import pty
import re
import select
import signal
import socket
import termios
import tty
from typing import Union

import stream_filter


class BaseProxy:
    """This class does the actual work of the pseudo terminal."""

    def __init__(self, app_name: str):
        """Create a spawned process."""
        parser = argparse.ArgumentParser(
            description="Run %s through a filtering proxy." % app_name)
        parser.add_argument('cmd', metavar='ARGS', nargs='+',
                            help='%s command with arguments' % app_name)
        parser.add_argument('-a', '--address', metavar='ADDR',
                            help='Local socket to receive commands.')
        args = parser.parse_args()

        self.server_address: str = args.address
        self.argv = args.cmd
        log_handler = logging.NullHandler() if not os.environ.get('CI') \
                else logging.FileHandler("proxy.log")
        logging.basicConfig(
            level=logging.DEBUG,
            format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            handlers=[log_handler])
        self.logger = logging.getLogger(type(self).__name__)
        self.logger.info("Starting proxy: %s", app_name)

        self.sock: Union[socket.socket, None] = None
        if self.server_address:
            # Create a UDS socket
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
            self.sock.bind(self.server_address)
            self.sock.settimeout(0.5)

        # Create the filter
        self.filter = [(stream_filter.Filter(), lambda _: None)]
        # Where was the last command received from?
        self.last_addr = None

        # Spawn the process in a PTY
        pid, self.master_fd = pty.fork()
        if pid == pty.CHILD:
            os.execvp(self.argv[0], self.argv)

    def run(self):
        """Run the proxy, the entry point."""
        old_handler = signal.signal(signal.SIGWINCH,
                                    lambda signum, frame: self._set_pty_size())

        mode = tty.tcgetattr(pty.STDIN_FILENO)
        tty.setraw(pty.STDIN_FILENO)

        self._set_pty_size()

        try:
            self._process()
        except OSError as os_err:
            self.logger.exception("Exception")
            # Avoid printing I/O Error that happens on every GDB quit
            if os_err.errno != errno.EIO:
                raise
        except Exception:
            self.logger.exception("Exception")
            raise
        finally:
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

    def set_filter(self, filt, handler):
        """Push a new filter with given handler."""
        self.logger.info("set_filter %s %s", str(filt), str(handler))
        if len(self.filter) == 1:
            self.logger.info("filter accepted")
            # Only one command at a time. Should be an assertion here,
            # but we wouldn't want to terminate the program.
            if self.filter:
                self._timeout()
            self.filter.append((filt, handler))
            return True
        self.logger.warning("filter rejected")
        return False

    @abc.abstractmethod
    def get_prompt(self):
        """Get a compiled regex to match the debugger prompt.

        The implementations should implement this.
        """

    def process_handle_command(self, cmd, response):
        """Process output of custom command."""
        self.logger.info("Process handle command %s bytes", len(response))
        # Assuming the prompt occupies the last line
        result = response[(len(cmd) + 1):response.rfind(b'\n')].strip()
        return result

    def filter_command(self, command):
        """Prepare a requested command for execution."""
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'handle-command':
            cmd = command[len('handle-command '):]
            res = self.set_filter(
                stream_filter.StreamFilter(self.get_prompt()),
                lambda resp: self.process_handle_command(cmd, resp))
            return cmd if res else b''
        return command

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
                rfds, _, _ = select.select(sockets, [], [], 0.25)
                self._process_reads(rfds)
            except OSError as ex:
                if ex.errno == errno.EAGAIN:   # Interrupted system call.
                    continue
                raise

    def _process_reads(self, rfds):
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
                    self.logger.warning(
                        "The command ending with <nl>. "
                        "The StreamProxy filter known to fail.")
                self.logger.info("Got command '%s'", data.decode('utf-8'))
                command = self.filter_command(data)
                self.logger.info("Translated command '%s'",
                                 command.decode('utf-8'))
                if command:
                    self.write_master(command)
                    self.write_master(b'\n')

    @staticmethod
    def _write(fdesc, data):
        """Write the data to the file."""
        while data:
            count = os.write(fdesc, data)
            data = data[count:]

    def _timeout(self):
        filt, _ = self.filter[-1]
        data = filt.timeout()
        self._write(pty.STDOUT_FILENO, data)
        # Get back to the passthrough filter on timeout
        if len(self.filter) > 1:
            self.filter.pop()

    def write_stdout(self, data):
        """Write to stdout for the child process."""
        self.logger.debug("%s", data)
        filt, handler = self.filter[-1]
        data, filtered = filt.filter(data)
        self._write(pty.STDOUT_FILENO, data)
        if filtered:
            self.logger.info("Filter matched %d bytes", len(filtered))
            self.filter.pop()
            assert callable(handler)
            res = handler(filtered)
            self.logger.debug("Sending to %s: %s", self.last_addr, res)
            self.sock.sendto(res, 0, self.last_addr)

    def write_master(self, data):
        """Write to the child process from its controlling terminal."""
        self._write(self.master_fd, data)

    def master_read(self, data):
        """Handle data from the child process."""
        self.write_stdout(data)

    def stdin_read(self, data):
        """Handle data from the controlling terminal."""
        self.write_master(data)
