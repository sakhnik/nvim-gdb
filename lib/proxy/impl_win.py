import msvcrt
import os
import selectors
import shutil
import sys
import threading
import traceback
import winpty

from base import Base


class ImplWin(Base):
    def __init__(self, app_name: str, argv: [str]):
        super().__init__(app_name, argv)

        console_size = shutil.get_terminal_size()
        rows, _ = console_size.lines, console_size.columns

        # Spawn the process in a PTY
        self.winproc = winpty.PtyProcess.spawn(self.argv,
                                               dimensions=(rows, 999))
        self.master_fd = self.winproc.fileno()
        self.mutex = threading.Lock()
        self.stdin_input = bytearray()
        self.selector.register(self.master_fd, selectors.EVENT_READ)
        self.thread = None

    def run(self):
        exitcode = 0

        try:
            self.thread = threading.Thread(target=self._stdin_thread)
            self.thread.start()
            super().run_loop()
        except EOFError:
            pass
        finally:
            self.winproc.close()
            print("Press any key to continue...")
            if self.thread.is_alive():
                self.thread.join()
            exitcode = self.winproc.wait()
            del self.winproc
            self.winproc = None
        return exitcode

    def _stdin_thread(self):
        msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
        while self.winproc.isalive():
            try:
                ch = msvcrt.getch()
                self.mutex.acquire()
                try:
                    self.stdin_input.extend(ch)
                finally:
                    self.mutex.release()
                self._process_stdin()
            except EOFError:
                break
            except Exception as e:
                self.logger.critical(f"Exception {e}")
                self.logger.info("%s", traceback.format_exc())

    def _process_stdin(self):
        try:
            self.mutex.acquire()
            if len(self.filter) == 1 and self.stdin_input:
                data = bytes(self.stdin_input)
                self.stdin_input = bytearray()
                self.stdin_read(data)
        except EOFError:
            pass
        except Exception as e:
            self.logger.warning(f"Exception: {e}")
            self.logger.info("%s", traceback.format_exc())
        finally:
            self.mutex.release()

    def _timeout(self):
        self._process_stdin()
        super()._timeout()

    def read_master(self) -> bytes:
        return self.winproc.read().encode('utf-8')

    def write_master(self, data):
        """Write to the child process from its controlling terminal."""
        self.winproc.write(data.decode('utf-8'))

    def filter_changed(self, added: bool):
        """Don't care about filter here"""
