"""The program injected into GDB to provide a side channel
to the plugin."""

import gdb
import json
import os
import re
import socket
import sys
import threading


class NvimGdbInit(gdb.Command):
    """Initialize a side channel for nvim-gdb."""

    def __init__(self):
        super(NvimGdbInit, self).__init__("nvim-gdb-init", gdb.COMMAND_OBSCURE)
        self.quit = True
        self.thrd = None
        self.fallback_to_parsing = False

    def invoke(self, arg, from_tty):
        if not self.thrd:
            self.quit = False
            self.thrd = threading.Thread(target=self._server, args=(arg,))
            self.thrd.daemon = True
            self.thrd.start()

    def exit_handler(self, event):
        self.quit = True
        if self.thrd and self.thrd.is_alive():
            self.thrd.join()

    def _server(self, server_address: str):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(('127.0.0.1', 0))
        sock.settimeout(0.25)
        _, port = sock.getsockname()
        with open(server_address, 'w') as f:
            f.write(f"{port}")
        try:
            while not self.quit:
                try:
                    data, addr = sock.recvfrom(65536)
                except TimeoutError:
                    continue
                command = re.split(r"\s+", data.decode("utf-8"))
                if command[0] == "info-breakpoints":
                    fname = command[1]
                    breaks = self._get_breaks(os.path.normpath(fname))
                    sock.sendto(breaks.encode("utf-8"), 0, addr)
                elif command[0] == "handle-command":
                    # pylint: disable=broad-except
                    try:
                        if command[1] == 'nvim-gdb-info-breakpoints':
                            # Fake a command info-breakpoins for
                            # GdbLopenBreakpoins
                            resp = self._get_all_breaks()
                            sock.sendto(resp.encode("utf-8"), 0, addr)
                            return
                        gdb_command = " ".join(command[1:])
                        if sys.version_info.major < 3:
                            gdb_command = gdb_command.encode("utf-8")
                        try:
                            result = gdb.execute(gdb_command, False, True)
                        except RuntimeError as err:
                            result = str(err)
                        result = b"" if result is None else \
                            result.encode("utf-8")
                        sock.sendto(result.strip(), 0, addr)
                    except Exception as ex:
                        print("Exception: " + str(ex))
        finally:
            try:
                os.unlink(server_address)
            except OSError:
                pass

    def _get_breaks_provider(self):
        # Older versions of GDB may lack attribute .locations in
        # the breakpoint class, will have to parse `info breakpoints` then.
        if not self.fallback_to_parsing:
            return self._enum_breaks()
        return self._enum_breaks_fallback()

    def _get_breaks(self, fname: str):
        """Get list of enabled breakpoints for a given source file."""
        breaks = {}

        try:
            for path, line, bid in self._get_breaks_provider():
                if fname == os.path.normpath(path):
                    breaks.setdefault(line, []).append(bid)
        except AttributeError:
            self.fallback_to_parsing = True
            return self._get_breaks(fname)

        # Return the filtered breakpoints
        return json.dumps(breaks)

    def _enum_breaks(self):
        """Get a list of all enabled breakpoints."""
        # Consider every breakpoint while skipping over the disabled ones
        for bp in gdb.breakpoints():
            if not bp.is_valid() or not bp.enabled:
                continue
            bid = bp.number
            for location in bp.locations:
                if not location.enabled or not location.source:
                    continue
                filename, line = location.source
                if location.fullname:
                    yield location.fullname, line, bid
                else:
                    yield filename, line, bid

    def _enum_breaks_fallback(self):
        """Get a list of all enabled breakpoints by parsing
        `info breakpoints` output."""

        # There can be up to two lines for one breakpoint, filename:lnum may be
        # on the second line if the screen is too narrow.
        bid = None
        response = gdb.execute('info breakpoints', False, True)
        for line in re.split(r"[\n\r]+", response):
            fields = re.split(r"[\s]+", line)

            if len(fields) >= 5 and re.match("0x[0-9a-zA-Z]+", fields[4]):
                if fields[3] != 'y':    # Is enabled?
                    bid = None
                else:
                    bid = re.match("[^.]+", fields[0]).group(0)

            if len(fields) >= 2 and fields[-2] == "at":
                # file.cpp:line
                m = re.match(r"^([^:]+):(\d+)$", fields[-1])
                if m and bid:
                    bpfname, lnum = m.group(1), m.group(2)
                    yield bpfname, lnum, bid

    def _get_all_breaks(self):
        """Get list of all enabled breakpoints suitable for location
        list."""
        breaks = []
        try:
            for path, line, bid in self._get_breaks_provider():
                breaks.append(f"{path}:{line} breakpoint {bid}")
        except AttributeError:
            self.fallback_to_parsing = True
            return self._get_all_breaks()
        return "\n".join(breaks)


init = NvimGdbInit()
gdb.events.exited.connect(init.exit_handler)
