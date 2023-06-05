from base_proxy import BaseProxy
import array
import errno
import fcntl
import os
import pty
import selectors
import signal
import sys
import termios
import tty


class UnixProxy(BaseProxy):
    def __init__(self, app_name: str):
        super().__init__(app_name)

        self.pid, self.master_fd = pty.fork()
        if self.pid == pty.CHILD:
            try:
                os.execvp(self.argv[0], self.argv)
            except OSError as e:
                sys.stderr.write(f"Failed to launch: {e}\n")
                os._exit(1)
        self.selector.register(self.master_fd, selectors.EVENT_READ)

    def run(self):
        old_handler = \
            signal.signal(signal.SIGWINCH,
                          lambda signum, frame: self._set_pty_size())
        self._set_pty_size()
        mode = tty.tcgetattr(sys.stdin.fileno())
        tty.setraw(sys.stdin.fileno())

        self.filter_changed(False)

        try:
            super().run()
        finally:
            _, systemstatus = os.waitpid(self.pid, 0)
            if systemstatus:
                if os.WIFSIGNALED(systemstatus):
                    self.exitstatus = os.WTERMSIG(systemstatus) + 128
                else:
                    self.exitstatus = os.WEXITSTATUS(systemstatus)
            else:
                self.exitstatus = 0

            os.close(self.master_fd)
            self.master_fd = None

            tty.tcsetattr(sys.stdin.fileno(), tty.TCSAFLUSH, mode)
            signal.signal(signal.SIGWINCH, old_handler)

    def _set_pty_size(self):
        """Set the window size of the child pty."""
        assert self.master_fd is not None
        buf = array.array('h', [0, 0, 0, 0])
        try:
            fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ, buf, True)
            fcntl.ioctl(self.master_fd, termios.TIOCSWINSZ, buf)
        except OSError as ex:
            # Avoid printing I/O Error that happens on every GDB quit
            if ex.errno != errno.EIO:
                self.logger.exception("Exception")

    def filter_changed(self, added: bool):
        # Don't handle user input while a side command is running.
        if added:
            if len(self.filter) == 2:
                self.selector.unregister(sys.stdin.fileno())
        else:
            if len(self.filter) == 1:
                self.selector.register(sys.stdin.fileno(),
                                       selectors.EVENT_READ)

    def write_master(self, data):
        """Write to the child process from its controlling terminal."""
        self._write(self.master_fd, data)
