"""Query breakpoints in a given file from GDB."""
import vim
import socket
import sys
import os


# TODO: generate random rendez-vous point
server_address = '/tmp/nvim-gdb-python-socket'

# Make sure the socket does not already exist
try:
    os.unlink(server_address)
except OSError:
    if os.path.exists(server_address):
        raise

# Create a UDS socket
sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
sock.bind(server_address)
sock.settimeout(0.5)

# File in question
fname = sys.argv[0]
proxy_addr = sys.argv[1]

# Let GDB send back the list of sources
command = 'server nvim-gdb-info-breakpoints %s %s\n' % (fname, server_address)
sock.sendto(command.encode('utf-8'), 0, proxy_addr)

# Receive the result from GDB
data, addr = sock.recvfrom(65536)

# Get rid of the rendez-vous point
try:
    os.unlink(server_address)
except OSError:
    pass

# Set return value for Vim
vim.command("let return_value = '" + data.decode('utf-8') + "'")
