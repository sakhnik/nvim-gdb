"""The program injected into LLDB to provide a side channel
to the plugin."""

import json
import lldb  # type: ignore
import logging
import os
import re
import socket
import sys
import threading


logger = logging.getLogger("lldb")
logger.setLevel(logging.DEBUG)
lhandl = logging.NullHandler() if not os.environ.get('CI') \
    else logging.FileHandler("lldb.log", encoding='utf-8')
fmt = "%(asctime)s [%(levelname)s]: %(message)s"
lhandl.setFormatter(logging.Formatter(fmt))
logger.addHandler(lhandl)


def get_current_frame_location(debugger: lldb.SBDebugger):
    target = debugger.GetSelectedTarget()
    process = target.GetProcess()
    thread = process.GetSelectedThread()
    frame = thread.GetSelectedFrame()

    if frame.IsValid():
        symbol_context = frame.GetSymbolContext(lldb.eSymbolContextEverything)
        line_entry = symbol_context.line_entry
        if line_entry.IsValid():
            filespec = line_entry.GetFileSpec()
            filepath = os.path.join(filespec.GetDirectory(),
                                    filespec.GetFilename())
            line = line_entry.GetLine()
            return [filepath, line]

    return []


def is_process_running(debugger: lldb.SBDebugger):
    target = debugger.GetSelectedTarget()
    process = target.GetProcess()
    state = process.GetState()
    return state == lldb.eStateRunning


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
    return breaks


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
    logger.info("Start listening for commands at port %d", port)

    # debugger = lldb.SBDebugger_FindDebuggerWithID(debugger_id)

    try:
        while True:
            data, addr = sock.recvfrom(65536)
            command = data.decode("utf-8")
            logger.debug("Got command: %s", command)
            command = re.split(r"\s+", command)
            req_id = int(command[0])
            request = command[1]
            args = command[2:]
            if request == "info-breakpoints":
                fname = args[0]
                # response_addr = command[3]
                response = {
                    "request": req_id,
                    "response": _get_breaks(os.path.normpath(fname), debugger)
                }
                sock.sendto(json.dumps(response).encode("utf-8"), 0, addr)
            elif request == "is-process-running":
                response = {
                    "request": req_id,
                    "response": is_process_running(debugger)
                }
                sock.sendto(json.dumps(response).encode("utf-8"), 0, addr)
            elif request == "get-current-frame-location":
                response = {
                    "request": req_id,
                    "response": get_current_frame_location(debugger)
                }
                sock.sendto(json.dumps(response).encode("utf-8"), 0, addr)
            elif request == "handle-command":
                # pylint: disable=broad-except
                try:
                    if args[0] == 'nvim-gdb-info-breakpoints':
                        # Fake a command info-breakpoins for GdbLopenBreakpoins
                        response = {
                            "request": req_id,
                            "response": _get_all_breaks(debugger)
                        }
                        sock.sendto(json.dumps(response).encode("utf-8"),
                                    0, addr)
                        return
                    command_to_handle = " ".join(args)
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
                    response = {
                        "request": req_id,
                        "response": "" if result is None else result.strip()
                    }
                    result = b"" if result is None else result.encode("utf-8")
                    sock.sendto(json.dumps(response).encode('utf-8'), 0, addr)
                except Exception as ex:
                    print("Exception: " + str(ex))
    finally:
        logger.info("Stop listening for commands")
        try:
            os.unlink(server_address)
        except OSError:
            pass


def init(debugger: lldb.SBDebugger, command: str, _3, _4):
    """Entry point."""
    server_address = command
    thrd = threading.Thread(target=_server, args=(server_address, debugger))
    thrd.start()
