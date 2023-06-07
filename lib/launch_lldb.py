#!/usr/bin/env python3

import os
import subprocess
import sys
import tempfile


# Prepare lldb initialization commands
this_dir = os.path.realpath(os.path.dirname(__file__))

# The script can be launched as `python3 script.py`
args_to_skip = 0 if os.path.basename(__file__) == sys.argv[0] else 1
argv = sys.argv[args_to_skip:]
server_addr = ''
if argv[0] == '-a':
    server_addr = argv[1]
    argv = argv[2:]

# Assuming the first argument is path to lldb, the rest are arguments.
# We'd like to ensure gdb is launched with our custom initialization
# injected.

# lldb command
lldb = argv[0]

# the rest are lldb arguments
argv = argv[1:]

# Create a named temporary file
with tempfile.NamedTemporaryFile() as lldb_init:
    lldb_init.write(f"command script import {this_dir}/lldb_commands.py\n"
                    .encode())
    lldb_init.write(b"command script add -f lldb_commands.init")
    lldb_init.write(b" nvim-gdb-init\n")
    lldb_init.write(f"nvim-gdb-init {server_addr}\n"
                    .encode())
    lldb_init.write(br"settings set frame-format")
    lldb_init.write(br" frame #${frame.index}: ${frame.pc}{")
    lldb_init.write(br" ${module.file.basename}{\`${function.name-with-args}")
    lldb_init.write(br"{${frame.no-debug}${function.pc-offset}}}}")
    lldb_init.write(br"{ at \032\032${line.file.fullpath}:${line.number}}")
    lldb_init.write(br"{${function.is-optimized} [opt]}\n")
    lldb_init.write(b"\n")
    lldb_init.write(b"settings set auto-confirm true\n")
    lldb_init.write(b"settings set stop-line-count-before 0\n")
    lldb_init.write(b"settings set stop-line-count-after 0\n")
    lldb_init.flush()
    # Execute lldb finally with our custom initialization script
    result = subprocess.run([lldb, '-S', lldb_init.name] + argv)
    sys.exit(result.returncode)
