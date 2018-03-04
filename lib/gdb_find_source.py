import vim
import socket
import sys
import os

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

vim.command('call nvimgdb#Send("nvim-gdb-info-sources %s")' % server_address)

data, addr = sock.recvfrom(65536)
print("received message:", data)

vim.command('let return_value = ["/tmp/nvim-gdb/test/test.cpp"]')
