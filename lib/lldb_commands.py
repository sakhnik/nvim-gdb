'''The program injected into LLDB to provide a side channel
to the plugin.'''

import json
import os
import re
import socket
import threading
import lldb  # type: ignore


# Get list of enabled breakpoints for a given source file
def _get_breaks(fname):
    breaks = {}

    # Ensure target is the actually selected one
    target = lldb.debugger.GetSelectedTarget()

    # Consider every breakpoint while skipping over the disabled ones
    for bpt in target.breakpoint_iter():
        if not bpt.IsEnabled():
            continue
        bid = bpt.GetID()

        # Consider every location of a breakpoint
        for loc in bpt:
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


class NvimGDB:
    '''*'''
    eBroadcastBitStopEventThread = 1 << 0

    def __init__(self):
        self.broadcaster = lldb.SBBroadcaster()
        self.connected = False
        self.sock_addr = "/tmp/idk/server"
        self.proxy_addr = "/tmp/idk/client"
        self.sock = None

    def set_sock(self, sock):
        '''.'''
        self.sock = sock

    def shutup_warning(self):
        '''.'''


G_NVIM_GDB = NvimGDB()


import pysnooper
@pysnooper.snoop("/tmp/idkwhat")
def process_event(server_address, listener):
    '''.'''
    G_NVIM_GDB.set_sock(socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM))
    G_NVIM_GDB.sock.bind("/tmp/idk/server")

    while True:
        try:
            G_NVIM_GDB.sock.connect("/tmp/idk/client")
            break
        except Exception as _:
            pass

    done = False
    event = lldb.SBEvent()
    while not done:
        if listener.WaitForEvent(1, event):
            event_mask = event.GetType()
            if lldb.SBProcess_EventIsProcessEvent(event):
                process = lldb.SBProcess_GetProcessFromEvent(event)
                if event_mask & lldb.SBProcess.eBroadcastBitStateChanged:
                    state = lldb.SBProcess_GetStateFromEvent(event)
                    if state == lldb.eStateInvalid:
                        pass
                    elif state == lldb.eStateUnloaded:
                        pass
                    elif state == lldb.eStateConnected:
                        pass
                    elif state == lldb.eStateAttaching:
                        pass
                    elif state == lldb.eStateLaunching:
                        pass
                    elif state == lldb.eStateCrashed:
                        pass
                    elif state == lldb.eStateDetached:
                        pass
                    elif state == lldb.eStateSuspended:
                        pass
                    elif state == lldb.eStateStopped:
                        if not lldb.SBProcess_GetRestartedFromEvent(event):
                            frame = process.selected_thread.frame[0]
                            file = frame.line_entry.file.fullpath
                            line = frame.line_entry.line
                            message = "fileline" + file + ":" + str(line)
                            G_NVIM_GDB.sock.send(message.encode("utf-8"))
                    elif state == lldb.eStateRunning:
                        pass
                    elif state == lldb.eStateExited:
                        # send exited event
                        pass
                elif (
                        event_mask & lldb.SBProcess.eBroadcastBitSTDOUT
                        or event_mask & lldb.SBProcess.eBroadcastBitSTDERR
                ):
                    # do nothing I think...?
                    pass
            elif lldb.SBBreakpoint_EventIsBreakpointEvent(event):
                if event_mask & lldb.SBTarget.eBroadcastBitBreakpointChanged:
                    event_type = lldb.SBBreakpoint_GetBreakpointEventTypeFromEvent(
                        event
                    )
                    num_locs = lldb.SBBreakpoint.GetNumBreakpointLocationsFromEvent(
                        event
                    )
                    #breakp = lldb.SBBreakpoint_GetBreakpointFromEvent(event)
                    added = event_type & lldb.eBreakpointEventTypeLocationsAdded
                    removed = event_type & lldb.eBreakpointEventTypeLocationsRemoved
                    if added or removed:
                        for i in range(0, num_locs):
                            bp_loc = lldb.SBBreakpoint_GetBreakpointLocationAtIndexFromEvent(
                                event, i
                            )
                            line_entry = bp_loc.GetAddress().GetLineEntry()
                            filename = line_entry.GetFileSpec().GetFilename()
                            line = line_entry.GetLine()
                            message = "breakpnt" + filename + str(line)
                            G_NVIM_GDB.sock.send(message.encode("utf-8"))
            elif lldb.SBThread_EventIsThreadEvent(event):
                pass
            # elif event.BroadcasterMatchesRef(g_nvim_gdb.broadcaster):
            #     if event_mask & nvim_gdb.eBroadcastBitStopEventThread:
            #         done = True

            # if not done:
            #     g_nvim_gdb.broadcaster.BroadcastEvent(event)



def init(debugger, command, _3, _4):
    '''Entry point.'''
    server_address = command
    thrd = threading.Thread(target=_server, args=(server_address,))
    thrd.start()

    # EnableForwardEvents was added in lldb 9.0.0. Simply fail and resort
    # to the old implementation if it doesn't exist
    try:
        #debugger.SetAsync(False)
        listener = lldb.SBListener("nvim-gdb")
        debugger.EnableForwardEvents(listener)
        #debugger.SetAsync(True)

        thrd2 = threading.Thread(target=process_event, args=(9021, listener))
        thrd2.start()
    except AttributeError:
        pass
