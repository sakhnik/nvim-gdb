#!/usr/bin/env python

import asyncio
import pipes
import sys

# rr replay refuses to run outside of a pty. But it allows
# attaching a gdb remotely.


async def run_gdb(cmd):
    args = "".join([f'"{pipes.quote(a)}"' for a in sys.argv[1:]])
    gdb_proc = await asyncio.create_subprocess_shell(cmd + ' ' + args)
    await gdb_proc.communicate()
    return gdb_proc.returncode


async def continue_rr(rr_proc):
    # Copy the rest of `rr replay` stderr to the terminal
    while not rr_proc.stderr.at_eof():
        line = await rr_proc.stderr.readline()
        print(line.decode(), file=sys.stderr)
    return await rr_proc.wait()


async def run(cmd):
    # First run the command `rr replay`
    rr_proc = await asyncio.create_subprocess_shell(
        cmd,
        stderr=asyncio.subprocess.PIPE)

    # Check it launched
    header = await rr_proc.stderr.readline()
    if header != b'Launch gdb with\n':
        raise RuntimeError("Unexpected rr replay output")

    # Get the advertised gdb command from the stderr
    gdb_cmd = await rr_proc.stderr.readline()

    # Continue to running both rr and gdb
    return await asyncio.gather(continue_rr(rr_proc),
                                run_gdb(gdb_cmd.decode()))


# Run `rr replay` selecting a random TCP port for GDB
asyncio.run(run("rr replay -s0"))
