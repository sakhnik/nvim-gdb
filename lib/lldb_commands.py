'''The program injected into LLDB to implement custom commands.'''

import os
import re
import json


# Get list of enabled breakpoints for a given source file
def _get_breaks(debugger, fname):
    breaks = {}

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

            # See whether the breakpoint is in the file in question
            if fname == path:
                line = lineentry.GetLine()
                try:
                    breaks[line].append(bid)
                except KeyError:
                    breaks[line] = [bid]

    # Return the filtered breakpoints
    return json.dumps(breaks)


def info_breakpoints(debugger, fname, _3, _4):
    """Query breakpoints."""
    breaks = _get_breaks(debugger, fname)
    print(breaks)


def __lldb_init_module(debugger, _2):
    debugger.HandleCommand('command script add -f' +
            ' lldb_commands.info_breakpoints nvim-gdb-info-breakpoints')
