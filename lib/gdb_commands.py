"""The program injected into GDB to provide a side channel
to the plugin."""

import gdb
import json
import logging
import os
import re
import socket
import sys
import threading


logger = logging.getLogger("gdb")
logger.setLevel(logging.DEBUG)
lhandl = logging.NullHandler() if not os.environ.get('CI') \
    else logging.FileHandler("gdb.log", encoding='utf-8')
fmt = "%(asctime)s [%(levelname)s]: %(message)s"
lhandl.setFormatter(logging.Formatter(fmt))
logger.addHandler(lhandl)


class NvimGdbInit(gdb.Command):
    """Initialize a side channel for nvim-gdb."""

    def __init__(self):
        super(NvimGdbInit, self).__init__("nvim-gdb-init", gdb.COMMAND_OBSCURE)
        self.quit = True
        self.thrd = None
        self.fallback_to_parsing = False
        self.state = "stopped"

        def handle_continue(event):
            self.state = "running"
        gdb.events.cont.connect(handle_continue)
        def handle_stop(event):
            self.state = "stopped"
        gdb.events.stop.connect(handle_stop)
        gdb.events.exited.connect(handle_stop)

    def invoke(self, arg, from_tty):
        if not self.thrd:
            self.quit = False
            self.thrd = threading.Thread(target=self._server, args=(arg,))
            self.thrd.daemon = True
            self.thrd.start()

    def _server(self, server_address):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(('127.0.0.1', 0))
        sock.settimeout(0.25)
        _, port = sock.getsockname()
        with open(server_address, 'w') as f:
            f.write(str(port))
        logger.info("Start listening for commands at port %d", port)
        try:
            while not self.quit:
                try:
                    data, addr = sock.recvfrom(65536)
                except socket.timeout:
                    continue
                command = data.decode("utf-8")
                self._handle_command(command, sock, addr)
        finally:
            logger.info("Stop listening for commands")
            try:
                os.unlink(server_address)
            except OSError:
                pass

    def _handle_command(self, command, sock, addr):
        logger.debug("Got command: %s", command)
        command = re.split(r"\s+", command)
        req_id = int(command[0])
        request = command[1]
        args = command[2:]
        if request == "info-breakpoints":
            fname = args[0]
            self._send_response(self._get_breaks(os.path.normpath(fname)),
                                req_id, sock, addr)
        elif request == "get-process-state":
            self._send_response(self._get_process_state(),
                                req_id, sock, addr)
        elif request == "get-current-frame-location":
            self._send_response(self._get_current_frame_location(),
                                req_id, sock, addr)
        elif request == "handle-command":
            # pylint: disable=broad-except
            try:
                # TODO Is this used?
                if args[0] == 'nvim-gdb-info-breakpoints':
                    # Fake a command info-breakpoins for
                    # GdbLopenBreakpoins
                    self._send_response(self._get_all_breaks(),
                                        req_id, sock, addr)
                    return
                gdb_command = " ".join(args)
                if sys.version_info.major < 3:
                    gdb_command = gdb_command.encode("utf-8")
                try:
                    result = gdb.execute(gdb_command, False, True)
                except RuntimeError as err:
                    result = str(err)
                if result is None:
                    result = ""
                self._send_response(result.strip(), req_id, sock, addr)
            except Exception as ex:
                logger.error("Exception: %s", ex)

    def _send_response(self, response, req_id, sock, addr):
        response_msg = {
            "request": req_id,
            "response": response
        }
        response_json = json.dumps(response_msg).encode("utf-8")
        logger.debug("Sending response: %s", response_json)
        sock.sendto(response_json, 0, addr)

    def _get_process_state(self):
        return self.state

    def _get_current_frame_location(self):
        try:
            frame = gdb.selected_frame()
            if frame is not None:
                symtab_and_line = frame.find_sal()
                if symtab_and_line.symtab is not None:
                    filename = symtab_and_line.symtab.fullname()
                    line = symtab_and_line.line
                    return [filename, line]
        except gdb.error:
            pass
        return []

    def _get_breaks_provider(self):
        # Older versions of GDB may lack attribute .locations in
        # the breakpoint class, will have to parse `info breakpoints` then.
        if not self.fallback_to_parsing:
            return self._enum_breaks()
        return self._enum_breaks_fallback()

    def _get_breaks(self, fname):
        """Get list of enabled breakpoints for a given source file."""
        breaks = {}

        try:
            for path, line, bid in self._get_breaks_provider():
                if fname.endswith(os.path.normpath(path)):
                    breaks.setdefault(line, []).append(bid)
        except AttributeError:
            self.fallback_to_parsing = True
            return self._get_breaks(fname)

        # Return the filtered breakpoints
        return breaks

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

        column_idx = {}
        header = response.splitlines()[0]
        contents = response.splitlines()[1:]

        for f in re.finditer(r"(\w+)\s*", header):
            s, e, str = f.start(), f.end(), f.group(1)
            e = None if e == len(header) else e
            column_idx[str] = (s, e)

        def get_column_value(line, column_name):
            if column_name not in column_idx:
                return ""
            s, e = column_idx[column_name]
            return line[s:e].strip()

        last_enabled = False

        for line in contents:
            bid, enabled, address, what = (
                get_column_value(line, "Num"),
                get_column_value(line, "Enb"),
                get_column_value(line, "Address"),
                get_column_value(line, "What"),
            )

            if enabled == '':
                enabled = last_enabled

            if not bid or enabled != 'y' or re.match(r"0x[0-9a-zA-Z]+", address) is None:
                continue

            bid = bid.split(".")[0]

            fields = re.split(r"\s+", what)
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
                breaks.append(str(path) + ':' + str(line) + ' breakpoint ' + str(bid))
        except AttributeError:
            self.fallback_to_parsing = True
            return self._get_all_breaks()
        return "\n".join(breaks)


init = NvimGdbInit()
