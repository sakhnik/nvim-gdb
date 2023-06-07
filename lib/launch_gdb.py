#!/usr/bin/env python3

import os
import sys
import tempfile
from proxy.gdb import Gdb


# Prepare gdb initialization commands
this_dir = os.path.realpath(os.path.dirname(__file__))

# The script can be launched as `python3 script.py`
args_to_skip = 0 if os.path.basename(__file__) == sys.argv[0] else 1
argv = sys.argv[args_to_skip:]
server_addr = ''
if argv[0] == '-a':
    server_addr = argv[1]
    argv = argv[2:]

# Assuming the first argument is path to gdb, the rest are arguments.
# We'd like to ensure gdb is launched with our custom initialization
# injected.

# gdb command
gdb = argv[0]
if gdb == 'rr-replay.py':
    gdb = os.path.join(this_dir, gdb)

# the rest are gdb arguments
argv = argv[1:]

# Create a named temporary directory (a temporary file wouldn't be accessible
# for other processes).
with tempfile.TemporaryDirectory() as dirname:
    gdb_init = os.path.join(dirname, "gdb_init")
    with open(gdb_init, "w") as f:
        f.write('set confirm off\n')
        f.write('set pagination off\n')
        f.write('set filename-display absolute\n')
        f.write(r'python gdb.prompt_hook = lambda p: p +')
        f.write(r' ("" if p.endswith("\x01\x1a\x1a\x1a\x02") else')
        f.write(r' "\x01\x1a\x1a\x1a\x02")')
    # Execute gdb finally through the proxy with our custom
    # initialization script
    args = ['-a', server_addr, gdb, '-f', '-ix', gdb_init] + argv
    gdb_proxy = Gdb(args)
    sys.exit(gdb_proxy.run())
