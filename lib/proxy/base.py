"""
Run a CLI application in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import abc
import argparse
import errno
import json
import logging
import os
import re
import selectors
import socket
import sys
from typing import Union

from stream_filter import Filter, StreamFilter


class Base:
    """This class does the actual work of the pseudo terminal."""

    def __init__(self, app_name: str, argv: [str]):
        """Create a spawned process."""
        parser = argparse.ArgumentParser(
            description="Run %s through a filtering proxy." % app_name)
        proxy_group = parser.add_argument_group("Proxy options")
        proxy_group.add_argument('-a', '--address', metavar='ADDR',
                                 help='File to dump" + \
                                 " the side channel UDP port')
        backend_group = parser.add_argument_group("Backend command")
        backend_group.add_argument('cmd', metavar='ARGS',
                                   nargs=argparse.REMAINDER,
                                   help=f'{app_name} command with arguments')
        args = parser.parse_args(argv)

        self.server_address: str = args.address
        self.argv = args.cmd
        log_handler = logging.NullHandler() if not os.environ.get('CI') \
            else logging.FileHandler("proxy.log", encoding='utf-8')
        logging.basicConfig(
            level=logging.DEBUG,
            format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            handlers=[log_handler])
        self.logger = logging.getLogger(type(self).__name__)
        self.logger.info("Starting proxy: %s", app_name)

        self.selector = selectors.DefaultSelector()

        self.sock: Union[socket.socket, None] = None
        if self.server_address:
            # Create a UDS socket
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.bind(('127.0.0.1', 0))
            self.sock.settimeout(0.5)
            self.selector.register(self.sock, selectors.EVENT_READ)
            _, port = self.sock.getsockname()
            with open(self.server_address, 'w') as f:
                f.write(f"{port}")

        # Create the filter
        self.filter = [(Filter(), -1, lambda _: None)]
        # The command queue, the command at the head is being processed
        # currently.
        self.command_queue: [(socket.socket, bytes)] = []

        # Last user command
        self.last_command = b''
        self.command_buffer = bytearray()

    def run_loop(self):
        """Run the proxy, the entry point."""
        try:
            while True:
                try:
                    rfds = [key.fileobj for key, _ in
                            self.selector.select(0.25)]
                    if not rfds:
                        self._timeout()
                        continue
                    self._process_reads(rfds)
                except OSError as ex:
                    if ex.errno == errno.EAGAIN:   # Interrupted system call.
                        continue
                    raise
        except OSError as os_err:
            # Avoid printing I/O Error that happens on every GDB quit
            if os_err.errno != errno.EIO:
                self.logger.exception("Exception")
                raise
        except Exception:
            self.logger.exception("Exception")
            raise
        finally:
            if self.server_address:
                try:
                    os.unlink(self.server_address)
                except OSError:
                    pass

    def set_filter(self, filt, req_id: int, handler):
        """Push a new filter with given handler."""
        self.logger.info("set_filter %s %s", str(filt), str(handler))
        # Only one command at a time.
        if len(self.filter) == 1:
            self.logger.info("filter accepted")
            self._timeout()
            self.filter.append((filt, req_id, handler))
            self.filter_changed(True)
            return True
        self.logger.warning("filter rejected")
        return False

    @abc.abstractmethod
    def filter_changed(self, added: bool):
        """Handle the filter added or removed."""

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
        m = re.match(rb'^(\d+) ([^ ]+) (.*)', command)
        if m and m.group(2) == b'handle-command':
            req_id = int(m.group(1))
            cmd = m.group(3)
            res = self.set_filter(
                StreamFilter(self.get_prompt()),
                req_id,
                lambda resp: self.process_handle_command(cmd, resp))
            assert res, "Only one filter is expected to be active at a time"
            return cmd
        return command

    def _process_reads(self, rfds):
        # Handle one packet at a time to mitigate the side channel
        # breaking into user input.
        if self.master_fd in rfds:
            # Reading the program's output
            data = self.read_master()
            self.write_stdout(data)
        elif sys.stdin.fileno() in rfds:
            # Reading user's input
            data = os.read(sys.stdin.fileno(), 1024)
            self.stdin_read(data)
        elif self.sock in rfds:
            data, sock = self.sock.recvfrom(65536)
            if data[-1] == b'\n':
                self.logger.warning(
                    "The command ending with <nl>. "
                    "The StreamProxy filter known to fail.")
            self.logger.info("Got command '%s'", data.decode('utf-8'))
            # Append the command to the queue, and kick off the command
            # processing
            self.command_queue.append((sock, data))
            if len(self.command_queue) == 1:
                self._send_command()

    def _send_command(self):
        sock, data = self.command_queue[0]
        command = self.filter_command(data)
        self.logger.info("Translated command '%s'", command.decode('utf-8'))
        if command:
            self.write_master(command)
            self.write_master(b"\n" if sys.platform != 'win32'
                              else b"\r\n")

    @staticmethod
    def _write(fdesc, data):
        """Write the data to the file."""
        while data:
            count = os.write(fdesc, data)
            data = data[count:]

    def _timeout(self):
        filt, _, _ = self.filter[-1]
        data = filt.timeout()
        self._write(sys.stdout.fileno(), data)
        # Get back to the passthrough filter on timeout
        if len(self.filter) > 1:
            self.filter.pop()
            self.filter_changed(False)

    def write_stdout(self, data):
        """Write to stdout for the child process."""
        self.logger.debug("Received: <%s>", data)
        filt, req_id, handler = self.filter[-1]
        data, filtered = filt.filter(data)
        self._write(sys.stdout.fileno(), data)
        if filtered:
            self.logger.info("Filter matched %d bytes", len(filtered))
            self.filter.pop()
            self.filter_changed(False)
            assert callable(handler)
            res = handler(filtered)
            sock, data = self.command_queue[0]
            self.command_queue = self.command_queue[1:]
            self.logger.debug("Sending to %s: %s", sock, res)
            response = {
                "request": req_id,
                "response": res.decode('utf-8')
            }
            self.sock.sendto(json.dumps(response).encode('utf-8'),
                             0, sock)
            # Proceed to the next command if any
            if self.command_queue:
                self._send_command()

    @abc.abstractmethod
    def read_master(self) -> bytes:
        """Read from the child process."""

    @abc.abstractmethod
    def write_master(self, data: bytes):
        """Write to the child process from its controlling terminal."""

    def stdin_read(self, data):
        """Handle data from the controlling terminal."""
        # Executing side commands messes with the command history.
        # Most popular debuggers use empty command to prepeat the last
        # command. We need to keep track of user commands to be able
        # to simulate the expected behaviour.
        self.command_buffer.extend(data)
        if re.fullmatch(b'[\r\n]', self.command_buffer):
            # Empty command detected, pass the last known command
            if self.last_command:
                self.logger.info("Repeat last command %s", self.last_command)
                self.write_master(self.last_command)
            else:
                self.write_master(data)
            self.command_buffer.clear()
        else:
            self.write_master(data)
            while True:
                m = re.search(b'[\n\r]', self.command_buffer)
                if not m:
                    break
                self.last_command = self.command_buffer[:m.end()+1]
                self.command_buffer = self.command_buffer[m.end()+1:]
