"""Find the path to the source by querying GDB."""
import vim
import socket
import sys
import os


# Find full path to a source file given by part of relative path.
# When a breakpoint is set, GDB may report with a relative path to the file.
# We need to know full path to the file. So we query all the known sources
# from GDB, and the find the ones that match the script argument.

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

# Let GDB send back the list of sources
vim.command('call nvimgdb#Send("server nvim-gdb-info-sources %s")'
            % server_address)

# Receive the result from GDB
data, addr = sock.recvfrom(65536)
lines = data.decode('utf-8').splitlines()

# What we are going to search for
target = os.path.normpath(sys.argv[0])
target_min_len = len(os.path.basename(target))
target = target[::-1]


def _LongestCommonPrefix(a, b):
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return i
    return n


# Filter those source paths that have the maximum suffix match with the target.
# Note that both the target and the sources are reversed now, so we are
# working with the prefixes.
m = target_min_len
result = []
for l in lines:
    x = _LongestCommonPrefix(target, l)
    if x > m:
        m = x
        result = [l[::-1]]
    elif x == m:
        result.append(l[::-1])

# Set return value for Vim
vim.command('let return_value = ' + str(result))
