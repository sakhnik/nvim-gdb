"""The program injected into GDB to provide a side channel
to the plugin."""

import gdb
import json
import logging
import os
import queue
import re
import socket
import sys
import threading

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

logger = logging.getLogger("gdb")
logger.setLevel(logging.DEBUG)
handler = (
    logging.FileHandler("gdb.log", encoding="utf-8")
    if os.environ.get("CI")
    else logging.NullHandler()
)
handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s]: %(message)s"))
logger.addHandler(handler)


# -----------------------------------------------------------------------------
# Command
# -----------------------------------------------------------------------------

class NvimGdbInit(gdb.Command):
    """Initialize a side channel for nvim-gdb."""

    def __init__(self):
        super().__init__("nvim-gdb-init", gdb.COMMAND_OBSCURE)

        self.quit = False
        self.thrd = None
        self.cmd_queue = queue.Queue()

        self.fallback_to_parsing = False
        self.state = "stopped"
        self.exited_or_ran = False

        # ---- GDB events (main thread only) -----------------------------------

        gdb.events.cont.connect(self._on_continue)
        gdb.events.stop.connect(self._on_stop)
        gdb.events.exited.connect(self._on_exit)

    # -------------------------------------------------------------------------
    # GDB event handlers (main thread)
    # -------------------------------------------------------------------------

    def _on_continue(self, event):
        self.state = "running"
        self.exited_or_ran = True

    def _on_stop(self, event):
        self.state = "stopped"

    def _on_exit(self, event):
        self.state = "stopped"
        self.exited_or_ran = True

    # -------------------------------------------------------------------------
    # GDB command entry
    # -------------------------------------------------------------------------

    def invoke(self, arg, from_tty):
        if self.thrd:
            return

        self.thrd = threading.Thread(
            target=self._server,
            args=(arg,),
            daemon=True,
        )
        self.thrd.start()

    # -------------------------------------------------------------------------
    # Background thread: socket server (NO gdb calls here)
    # -------------------------------------------------------------------------

    def _server(self, server_address):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(("127.0.0.1", 0))
        sock.settimeout(0.25)

        _, port = sock.getsockname()
        with open(server_address, "w") as f:
            f.write(str(port))

        logger.info("Listening on UDP port %d", port)

        try:
            while not self.quit:
                try:
                    data, addr = sock.recvfrom(65536)
                except socket.timeout:
                    continue

                try:
                    command = data.decode("utf-8")
                except Exception:
                    continue

                # enqueue for main thread
                self.cmd_queue.put((command, sock, addr))
                gdb.post_event(self._process_queue)

        finally:
            try:
                os.unlink(server_address)
            except OSError:
                pass

    # -------------------------------------------------------------------------
    # Main thread dispatcher
    # -------------------------------------------------------------------------

    def _process_queue(self):
        while not self.cmd_queue.empty():
            command, sock, addr = self.cmd_queue.get()
            try:
                self._dispatch_command(command, sock, addr)
            except Exception as exc:
                logger.error("Command failed: %s", exc)

    # -------------------------------------------------------------------------
    # Main-thread command handling (ALL gdb.* calls live here)
    # -------------------------------------------------------------------------

    def _dispatch_command(self, command, sock, addr):
        logger.debug("Got command: %s", command)

        parts = re.split(r"\s+", command)
        req_id = int(parts[0])
        request = parts[1]
        args = parts[2:]

        if request == "info-breakpoints":
            result = self._get_breaks(os.path.normpath(args[0]))

        elif request == "get-process-state":
            result = self.state

        elif request == "get-current-frame-location":
            result = self._get_current_frame_location()

        elif request == "has-exited-or-ran":
            result = self._get_reset_exited_or_ran()

        elif request == "handle-command":
            result = self._handle_gdb_command(args)

        else:
            result = ""

        self._send_response(result, req_id, sock, addr)

    # -------------------------------------------------------------------------
    # Helpers (main thread)
    # -------------------------------------------------------------------------

    def _handle_gdb_command(self, args):
        if args and args[0] == "nvim-gdb-info-breakpoints":
            return self._get_all_breaks()

        cmd = " ".join(args)
        if sys.version_info.major < 3:
            cmd = cmd.encode("utf-8")

        try:
            return gdb.execute(cmd, False, True) or ""
        except RuntimeError as err:
            return str(err)

    def _send_response(self, response, req_id, sock, addr):
        msg = json.dumps({
            "request": req_id,
            "response": response,
        }).encode("utf-8")
        sock.sendto(msg, addr)

    def _get_reset_exited_or_ran(self):
        if self.exited_or_ran:
            self.exited_or_ran = False
            return True
        return False

    def _get_current_frame_location(self):
        try:
            frame = gdb.selected_frame()
            if not frame:
                return []
            sal = frame.find_sal()
            if sal.symtab:
                return [sal.symtab.fullname(), sal.line]
        except gdb.error:
            pass
        return []

    # -------------------------------------------------------------------------
    # Breakpoints
    # -------------------------------------------------------------------------

    def _get_breaks_provider(self):
        if not self.fallback_to_parsing:
            return self._enum_breaks()
        return self._enum_breaks_fallback()

    def _get_breaks(self, fname):
        result = {}
        try:
            for path, line, bid in self._get_breaks_provider():
                if fname.endswith(os.path.normpath(path)):
                    result.setdefault(line, []).append(bid)
        except AttributeError:
            self.fallback_to_parsing = True
            return self._get_breaks(fname)
        return result

    def _enum_breaks(self):
        for bp in gdb.breakpoints() or []:
            if not bp.is_valid() or not bp.enabled:
                continue
            for loc in bp.locations:
                if not loc.enabled or not loc.source:
                    continue
                filename, line = loc.source
                yield (loc.fullname or filename), line, bp.number

    def _enum_breaks_fallback(self):
        text = gdb.execute("info breakpoints", False, True)
        lines = text.splitlines()[1:]

        for line in lines:
            m = re.search(r"(\d+)\s+y\s+0x[0-9a-fA-F]+\s+.* at ([^:]+):(\d+)", line)
            if m:
                yield m.group(2), int(m.group(3)), m.group(1)

    def _get_all_breaks(self):
        out = []
        for path, line, bid in self._get_breaks_provider():
            out.append(f"{path}:{line} breakpoint {bid}")
        return "\n".join(out)


# -----------------------------------------------------------------------------
# Register command
# -----------------------------------------------------------------------------

NvimGdbInit()
