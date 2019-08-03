'''The program injected into LLDB to provide a side channel
to the plugin.'''

import threading
import os
import socket
import re
import json
import lldb  # type: ignore


# Get list of enabled breakpoints for a given source file
def _get_breaks(fname):
    breaks = {}

    # Ensure target is the actually selected one
    target = lldb.debugger.GetSelectedTarget()

    # Consider every breakpoint while skipping over the disabled ones
    for bidx in range(target.GetNumBreakpoints()):
        bpt = target.GetBreakpointAtIndex(bidx)
        if not bpt.IsEnabled():
            continue
        bid = bpt.GetID()

        # Consider every location of a breakpoint
        for lidx in range(bpt.GetNumLocations()):
            loc = bpt.GetLocationAtIndex(lidx)
            lineentry = loc.GetAddress().GetLineEntry()
            filespec = lineentry.GetFileSpec()
            filename = filespec.GetFilename()
            if not filename:
                continue
            path = os.path.join(filespec.GetDirectory(), filename)

            # See whether the breakpoint is in the file in question
            if fname == path:
                line = lineentry.GetLine()
                try:
                    breaks[line].append(bid)
                except KeyError:
                    breaks[line] = [bid]

    # Return the filtered breakpoints
    return json.dumps(breaks)


def _server(server_address):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.bind(server_address)

    try:
        while True:
            data, addr = sock.recvfrom(65536)
            command = re.split(r'\s+', data.decode('utf-8'))
            if command[0] == "info-breakpoints":
                fname = command[1]
                # response_addr = command[3]
                breaks = _get_breaks(fname)
                sock.sendto(breaks.encode('utf-8'), 0, addr)
            elif command[0] == "handle-command":
                # pylint: disable=broad-except
                try:
                    command_to_handle = " ".join(command[1:]).encode('ascii')
                    return_object = lldb.SBCommandReturnObject()
                    lldb.debugger.GetCommandInterpreter().HandleCommand(
                        command_to_handle, return_object)
                    result = ''
                    if return_object.GetError():
                        result += return_object.GetError()
                    if return_object.GetOutput():
                        result += return_object.GetOutput()
                    result = b'' if result is None else result.encode('utf-8')
                    sock.sendto(result.strip(), 0, addr)
                except Exception as ex:
                    print("Exception " + str(ex))
    finally:
        try:
            os.unlink(server_address)
        except OSError:
            pass


def init(_1, command, _3, _4):
    '''Entry point.'''
    server_address = command
    thrd = threading.Thread(target=_server, args=(server_address,))
    thrd.start()
