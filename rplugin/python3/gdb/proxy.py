import os
import socket


class Proxy:
    def __init__(self, vim, proxyAddr, sockDir):
        self.vim = vim
        self.proxyAddr = proxyAddr
        self.sockAddr = os.path.join(sockDir.get(), "client")

        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.sock.bind(self.sockAddr)
        self.sock.settimeout(0.5)
        # Will connect to the socket later, when the first query is needed
        # to be issued.
        self.connected = False

    def cleanup(self):
        if self.sock:
            self.sock.close()
        os.remove(self.sockAddr)

    def ensureConnected(self):
        if not self.connected:
            try:
                self.sock.connect(self.proxyAddr)
                self.connected = True
            except OSError as msg:
                self.vim.command("echo 'Breakpoint: not connected to the proxy: %s'" % msg)
        return self.connected

    def query(self, request):
        # It takes time for the proxy to open a side channel.
        # So we're connecting to the socket lazily during
        # the first query.
        if self.ensureConnected():
            self.sock.send(request)
            return self.sock.recv(65536)
        return b''
