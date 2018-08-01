import threading
import os
import socket
import re
import json
import lldb


# Get list of enabled breakpoints for a given source file
def _GetBreaks(fname):
    breaks = {}

    # Ensure target is the actually selected one
    target = lldb.debugger.GetSelectedTarget()

    # Consider every breakpoint while skipping over the disabled ones
    for breakpoint in target.breakpoint_iter():
        if not breakpoint.IsEnabled():
            continue
        bid = breakpoint.GetID()

        # Consider every location of a breakpoint
        for loc in breakpoint:
            lineentry = loc.GetAddress().GetLineEntry()
            filespec = lineentry.GetFileSpec()
            path = os.path.join(filespec.GetDirectory(),
                                filespec.GetFilename())

            # See whether the breakpoint is in the file in question
            if fname == path:
                breaks[lineentry.GetLine()] = bid

    # Return the filtered breakpoints
    return json.dumps(breaks)


def server(server_address):
    # Make sure the socket does not already exist
    try:
        os.unlink(server_address)
    except OSError:
        pass

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.bind(server_address)

    try:
        while True:
            data, addr = sock.recvfrom(65536)
            command = re.split(r'\s+', data.decode('utf-8'))
            if command[0] == "info-breakpoints":
                fname = command[1]
                # response_addr = command[3]
                breaks = _GetBreaks(fname)
                sock.sendto(breaks.encode('utf-8'), 0, addr)
    finally:
        try:
            os.unlink(server_address)
        except OSError:
            pass


def init(debugger, command, result, internal_dict):
    server_address = command
    t = threading.Thread(target=server, args=(server_address,))
    t.start()
