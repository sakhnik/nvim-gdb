#!/usr/bin/env python3

import os
import shutil
import socket
import subprocess
import sys
import threading
import time
from spy_ui import SpyUI


class Nvim:
    def __init__(self):
        self.spy = None
        self.thread = None

    def wait_for_port(self, host, port):
        for i in range(10):
            try:
                with socket.create_connection((host, port), timeout=0.1):
                    return
            except (socket.timeout, ConnectionRefusedError):
                time.sleep(0.1)
        raise TimeoutError(f"Timeout waiting for port {port} on {host}")

    def run_spy_ui(self):
        self.wait_for_port('localhost', 44444)
        terminal_size = shutil.get_terminal_size()
        rows, columns = terminal_size.lines, terminal_size.columns
        self.spy = SpyUI(width=columns, height=rows)
        self.spy.run()

    def run(self, args):
        if os.getenv("CI"):
            self.thread = threading.Thread(target=self.run_spy_ui)
            self.thread.start()

        command = ['nvim', '--clean', '-u', 'NONE', '+source init.vim',
                   '--listen', 'localhost:44444']
        command.extend(args)

        result = subprocess.run(command)
        if self.thread and self.thread.is_alive():
            self.thread.join()
        return result.returncode


if __name__ == "__main__":
    # The script can be launched as `python3 script.py`
    args_to_skip = 0 if os.path.basename(__file__) == sys.argv[0] else 1
    sys.exit(Nvim().run(sys.argv[args_to_skip:]))
