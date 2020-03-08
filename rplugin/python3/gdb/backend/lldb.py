"""LLDB specifics."""

import json
import logging
import re
from gdb import parser
from gdb.backend import base


class Lldb:
    """LLDB parser and FSM."""

    command_map = {
        'delete_breakpoints': 'breakpoint delete',
        'breakpoint': 'b',
        'until {}': 'thread until {}',
    }

    def dummy1(self):
        """Treat the linter."""

    def dummy2(self):
        """Treat the linter."""

    class Parser(parser.Parser):
        """Parse LLDB output and manage FSM."""

        def __init__(self, common, cursor, win):
            """ctor."""
            super().__init__(common, cursor, win)

            re_prompt = re.compile(r'\s\(lldb\) $')
            self.add_trans(self.paused,
                           re.compile(r'[\r\n]Process \d+ resuming'),
                           self._paused_continue)
            self.add_trans(self.paused,
                           re.compile(r' at ([^:]+):(\d+)'),
                           self._paused_jump)
            self.add_trans(self.paused, re_prompt, self._query_b)
            self.add_trans(self.running,
                           re.compile(r'[\r\n]Breakpoint \d+:'),
                           self._query_b)
            self.add_trans(self.running,
                           re.compile(r'[\r\n]Process \d+ stopped'),
                           self._query_b)
            self.add_trans(self.running, re_prompt, self._query_b)

            self.state = self.running

    class Breakpoint(base.BaseBreakpoint):
        """Query breakpoints from the side channel."""

        def __init__(self, proxy):
            """ctor."""
            self.proxy = proxy
            self.logger = logging.getLogger("Gdb.Breakpoint")

        def query(self, fname: str):
            """Query actual breakpoints for the given file."""
            self.logger.info("Query breakpoints for %s", fname)
            resp = self.proxy.query(f"info-breakpoints {fname}\n")
            if not resp:
                return {}
            # We expect the proxies to send breakpoints for a given file
            # as a map of lines to array of breakpoint ids set in those lines.
            breaks = json.loads(resp)
            err = breaks.get('_error', None)
            if err:
                # self.vim.command(f"echo \"Can't get breakpoints: {err}\"")
                return {}
            return breaks
