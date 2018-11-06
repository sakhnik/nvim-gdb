"""Query breakpoints in a given file from GDB."""
import vim
import socket
import os
import tempfile
import json


class ClientSet:
    def __init__(self):
        self.sockets = {}

    def GetSocket(self, proxy_addr):
        try:
            sock, _ = self.sockets[proxy_addr]
            return sock
        except KeyError:
            pass

        # Cleanup outdated sockets.
        for addr, (sock, dname) in self.sockets.items():
            if not os.path.exists(addr):
                dname.cleanup()
                sock.close()
                self.sockets.pop(addr, None)

        # Let's put our unix socket into a random directory to avoid races
        dname = tempfile.TemporaryDirectory()
        # Create a UDS socket
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        # Bind the socket to be able to receive responses
        sock.bind(os.path.join(dname.name, 'sock'))
        # Break out after 1/2 second
        sock.settimeout(0.5)
        # Connect to the proxy
        sock.connect(proxy_addr)

        self.sockets[proxy_addr] = (sock, dname)
        return sock


client_set = ClientSet()

def InfoBreakpoints(fname, proxy_addr):
    try:
        sock = client_set.GetSocket(proxy_addr)

        # Let GDB send back the list of sources
        command = 'info-breakpoints %s\n' % fname
        sock.send(command.encode('utf-8'))

        # Receive the result from GDB
        data = sock.recv(65536)

        # Return the result to Vim
        return data.decode('utf-8')

    except Exception as e:
        return json.dumps({"_error": e.__str__()})
