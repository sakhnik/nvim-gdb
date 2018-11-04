"""Query breakpoints in a given file from GDB."""
import vim
import socket
import os
import tempfile
import json


def InfoBreakpoints(fname, proxy_addr):
    try:
        # Let's put our unix socket into a random directory to avoid races
        with tempfile.TemporaryDirectory() as dname:

            # Create a UDS socket
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
            # Bind the socket to be able to receive responses
            sock.bind(os.path.join(dname, 'sock'))
            # Break out after 1/2 second
            sock.settimeout(0.5)

            # Connect to the proxy
            sock.connect(proxy_addr)

            # Let GDB send back the list of sources
            command = 'info-breakpoints %s\n' % fname
            sock.send(command.encode('utf-8'))

            # Receive the result from GDB
            data = sock.recv(65536)

            # Return the result to Vim
            return data.decode('utf-8')

    except Exception as e:
        return json.dumps({"_error": e.__str__()})
