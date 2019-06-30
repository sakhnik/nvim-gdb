'''Connection to the side channel.'''

import os
import socket


class Proxy:
    '''Proxy to the side channel.'''
    def __init__(self, vim, proxy_addr, sock_dir):
        self.vim = vim
        self.proxy_addr = proxy_addr
        self.sock_addr = os.path.join(sock_dir.get(), "client")

        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.sock.bind(self.sock_addr)
        self.sock.settimeout(0.5)
        # Will connect to the socket later, when the first query is needed
        # to be issued.
        self.connected = False

    def cleanup(self):
        '''The destructor.'''
        if self.sock:
            self.sock.close()
        try:
            os.remove(self.sock_addr)
        except FileNotFoundError:
            pass

    def _ensure_connected(self):
        if not self.connected:
            try:
                self.sock.connect(self.proxy_addr)
                self.connected = True
            except OSError as msg:
                self.vim.command("echo 'Breakpoint: not connected"
                                 f" to the proxy: {msg}'")
        return self.connected

    def query(self, request):
        '''Send a request to the proxy and wait for the response.'''
        # It takes time for the proxy to open a side channel.
        # So we're connecting to the socket lazily during
        # the first query.
        if self._ensure_connected():
            self.sock.send(request.encode('utf-8'))
            return self.sock.recv(65536).decode('utf-8')
        return ''
