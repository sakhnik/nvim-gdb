#!/usr/bin/env python3

import os
import sys
import tempfile
from gdb_proxy import GdbProxy


# Prepare gdb initialization commands
this_dir = os.path.realpath(os.path.dirname(__file__))

argv = sys.argv
server_addr = ''
if argv[1] == '-a':
    server_addr = argv[2]
    argv = argv[3:]

# Assuming the first argument is path to gdb, the rest are arguments.
# We'd like to ensure gdb is launched with our custom initialization
# injected.

# gdb command
gdb = argv[0]
if gdb == 'rr-replay.py':
    gdb = os.path.join(this_dir, gdb)

# the rest are gdb arguments
argv = argv[1:]

# Create a named temporary file
with tempfile.NamedTemporaryFile() as gdb_init:
    gdb_init.write(br'''
set confirm off
set pagination off
set filename-display absolute
python gdb.prompt_hook = lambda p: p + ("" if p.endswith("\x01\x1a\x1a\x1a\x02") else "\x01\x1a\x1a\x1a\x02")
                    ''')
    gdb_init.flush()
    # Execute gdb finally through the proxy with our custom
    # initialization script
    args = ['-a', server_addr, gdb, '-f', '-ix', gdb_init.name] + argv
    gdb_proxy = GdbProxy(args)
    sys.exit(gdb_proxy.run())
