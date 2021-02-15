"""Connection to the side channel."""

import os
import socket
from gdb.common import Common
from gdb.client import Client


class Proxy(Common):
    """Proxy to the side channel."""

    def __init__(self, common: Common, client: Client):
        """ctor."""
        super().__init__(common)
        self.proxy_addr = client.get_proxy_addr()
        self.sock_addr = os.path.join(client.get_sock_dir(), "client")

        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.sock.bind(self.sock_addr)
        self.sock.settimeout(0.5)
        # Will connect to the socket later, when the first query is needed
        # to be issued.
        self.connected = False

    def cleanup(self):
        """destructor."""
        if self.sock:
            self.sock.close()
        try:
            os.remove(self.sock_addr)
        except FileNotFoundError:
            pass

    def _ensure_connected(self) -> bool:
        if not self.connected:
            try:
                self.sock.connect(self.proxy_addr)
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
