"""The program injected into LLDB to provide a side channel
to the plugin."""

import threading
import os
import socket
import sys
import re
import json
import lldb  # type: ignore


# Get list of enabled breakpoints for a given source file
def _enum_breaks(debugger: lldb.SBDebugger):
    # Ensure target is the actually selected one
    target = debugger.GetSelectedTarget()

    # Consider every breakpoint while skipping over the disabled ones
    for bidx in range(target.GetNumBreakpoints()):
        bpt = target.GetBreakpointAtIndex(bidx)
        if not bpt.IsEnabled():
            continue
        bid = str(bpt.GetID())

        # Consider every location of a breakpoint
        for lidx in range(bpt.GetNumLocations()):
            loc = bpt.GetLocationAtIndex(lidx)
            lineentry = loc.GetAddress().GetLineEntry()
            filespec = lineentry.GetFileSpec()
            filename = filespec.GetFilename()
            if not filename:
                continue
            path = os.path.join(filespec.GetDirectory(), filename)

            yield path, lineentry.GetLine(), bid


# Get list of enabled breakpoints for a given source file
def _get_breaks(fname, debugger: lldb.SBDebugger):
    breaks = {}

    for path, line, bid in _enum_breaks(debugger):
        # See whether the breakpoint is in the file in question
        if fname == os.path.normpath(path):
            try:
                breaks[line].append(bid)
            except KeyError:
                breaks[line] = [bid]

    # Return the filtered breakpoints
    return json.dumps(breaks)


# Get list of all enabled breakpoints suitable for location list
def _get_all_breaks(debugger: lldb.SBDebugger):
    breaks = []

    for path, line, bid in _enum_breaks(debugger):
        breaks.append(f"{path}:{line} breakpoint {bid}")

    return "\n".join(breaks)


def _server(server_address: str, debugger: lldb.SBDebugger):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('127.0.0.1', 0))
    _, port = sock.getsockname()
    with open(server_address, 'w') as f:
        f.write(f"{port}")

    # debugger = lldb.SBDebugger_FindDebuggerWithID(debugger_id)

    try:
        while True:
            data, addr = sock.recvfrom(65536)
            command = re.split(r"\s+", data.decode("utf-8"))
            if command[0] == "info-breakpoints":
                fname = command[1]
                # response_addr = command[3]
                breaks = _get_breaks(os.path.normpath(fname), debugger)
                sock.sendto(breaks.encode("utf-8"), 0, addr)
            elif command[0] == "handle-command":
                # pylint: disable=broad-except
                try:
                    if command[1] == 'nvim-gdb-info-breakpoints':
                        # Fake a command info-breakpoins for GdbLopenBreakpoins
                        resp = _get_all_breaks(debugger)
                        sock.sendto(resp.encode("utf-8"), 0, addr)
                        return
                    command_to_handle = " ".join(command[1:])
                    if sys.version_info.major < 3:
                        command_to_handle = command_to_handle.encode("ascii")
                    return_object = lldb.SBCommandReturnObject()
                    debugger.GetCommandInterpreter().HandleCommand(
                        command_to_handle, return_object
                    )
                    result = ""
                    if return_object.GetError():
                        result += return_object.GetError()
                    if return_object.GetOutput():
                        result += return_object.GetOutput()
                    result = b"" if result is None else result.encode("utf-8")
                    sock.sendto(result.strip(), 0, addr)
                except Exception as ex:
                    print("Exception: " + str(ex))
    finally:
        try:
            os.unlink(server_address)
        except OSError:
            pass


def init(debugger: lldb.SBDebugger, command: str, _3, _4):
    """Entry point."""
    server_address = command
    thrd = threading.Thread(target=_server, args=(server_address, debugger))
    thrd.start()
