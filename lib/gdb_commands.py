"""Custom GDB commands for nvim-gdb."""
import re
import socket
import json


class InfoSources(gdb.Command):
    """
    A custom GDB command to list all source files and send it to a socket.

    The files names will be reversed and sorted to simplify searching
    by basename.
    """

    def __init__(self):
        """Register the command."""
        super(InfoSources, self).__init__("nvim-gdb-info-sources",
                                          gdb.COMMAND_NONE)

    def invoke(self, arg, from_tty):
        """Execute the command."""
        output = gdb.execute('info sources', from_tty=False, to_string=True)
        sources = "\n".join(sorted([f.group(0)[::-1] for f in
                                    re.finditer(r'/[^, \n]+', output)]))
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        sock.sendto(sources.encode('utf-8'), arg)


InfoSources()


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
        breaks = []
        for line in output:
            fields = re.split("\s+", line)
            if fields[3] == 'y':    # Is enabled?
                m = pattern.fullmatch(fields[-1])   # file.cpp:line
                if (m and path.endswith(m.group(1))):
                    breaks.append((int(m.group(2)), int(fields[0])))

        ret = json.dumps(breaks)

        # Send the result to the given local socket
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        sock.sendto(ret.encode('utf-8'), sockaddr)


InfoBreakpoints()
