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
lines = data.decode('utf-8').splitlines()
target = os.path.normpath(sys.argv[0])
target_min_len = len(os.path.basename(target))
target = target[::-1]

def LongestCommonPrefix(a, b):
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return i
    return n

m = target_min_len
result = []
for l in lines:
    x = LongestCommonPrefix(target, l)
    if x > m:
        m = x
        result = [l[::-1]]
    elif x == m:
        result.append(l[::-1])

vim.command('let return_value = ' + str(result))
