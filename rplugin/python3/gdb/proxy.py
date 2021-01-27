"""Connection to the side channel."""

import os
import socket
from gdb.common import Common


class Proxy(Common):
    """Proxy to the side channel."""

    def __init__(self, common: Common):
        """ctor."""
        super().__init__(common)
        self.proxy_addr = self.vim.exec_lua("return nvimgdb.i().client:get_proxy_addr()")

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(('127.0.0.1', 0))
        self.sock.settimeout(0.5)
        # Will connect to the socket later, when the first query is needed
        # to be issued.
        self.connected = False

    def cleanup(self):
        """destructor."""
        if self.sock:
            self.sock.close()

    def _ensure_connected(self) -> bool:
        if not self.connected:
            try:
                server_port = None
                with open(self.proxy_addr, "r") as f:
                    server_port = int(f.readline())
                self.sock.connect(('127.0.0.1', server_port))
                self.connected = True
            except OSError as msg:
                self.vim.command("echo 'Breakpoint: not connected"
                                 f" to the proxy: {msg}'")
        return self.connected

    def query(self, request) -> str:
        """Send a request to the proxy and wait for the response."""
        # It takes time for the proxy to open a side channel.
        # So we're connecting to the socket lazily during
        # the first query.
        if self._ensure_connected():
            self.sock.send(request.encode('utf-8'))
            return self.sock.recv(65536).decode('utf-8')
        return ''
