"""Custom GDB commands for nvim-gdb."""
import re
import socket


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
        output = gdb.execute('info breakpoints', from_tty=False, to_string=True)
        # Parse the output for (file, line)
        locations = ((f.group(1), f.group(2)) for f in re.finditer(r' at ([^:]+):(\d+)', output))
        # Filter breakpoints supposedly belonging to the file in question
        breaks = [ln for (fl, ln) in locations if path.endswith(fl)]
        # Send the result to the given local socket
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        sock.sendto(" ".join(breaks).encode('utf-8'), sockaddr)


InfoBreakpoints()
