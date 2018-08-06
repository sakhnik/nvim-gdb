"""Query breakpoints in a given file from GDB."""
import vim
import socket
import os
import tempfile


def InfoBreakpoints(fname, proxy_addr):
    # Let's put our unix socket into a random directory to avoid races
    with tempfile.TemporaryDirectory() as dname:

        # Create a UDS socket
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        # Bind the socket to be able to receive responses
        sock.bind(os.path.join(dname, 'sock'))
        # Break out after 1/2 second
        sock.settimeout(0.5)

        # Let GDB send back the list of sources
        command = 'info-breakpoints %s\n' % fname
        sock.sendto(command.encode('utf-8'), 0, proxy_addr)

        # Receive the result from GDB
        data, addr = sock.recvfrom(65536)

        # Return the result to Vim
        return data.decode('utf-8')
