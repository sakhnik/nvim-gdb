"""Custom GDB commands for nvim-gdb."""
import re
import socket
import json


class InfoBreakpoints(gdb.Command):
    """
    A custom GDB command to list all breakpoints for a given source file
    """

    def __init__(self):
        """Register the command."""
        super(InfoBreakpoints, self).__init__("nvim-gdb-info-breakpoints",
                                              gdb.COMMAND_NONE)

    def invoke(self, arg, from_tty):
        """Execute the command."""
        args = arg.split(" ")
        path = args[0]        # Path to the listed file
        sockaddr = args[1]    # Local socket address to send the result to

        # List all breakpoints.
        output = gdb.execute('info breakpoints',
                             from_tty=False, to_string=True).splitlines()

        # Select lines in the current file with enabled breakpoints.
        pattern = re.compile("([^:]+):(\d+)")
        breaks = {}   # TODO: support more than one breakpoint per line
        for line in output:
            fields = re.split("\s+", line)
            if fields[3] == 'y':    # Is enabled?
                m = pattern.fullmatch(fields[-1])   # file.cpp:line
                if (m and path.endswith(m.group(1))):
                    breaks[int(m.group(2))] = int(fields[0])

        ret = json.dumps(breaks)

        # Send the result to the given local socket
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        sock.sendto(ret.encode('utf-8'), sockaddr)


InfoBreakpoints()
