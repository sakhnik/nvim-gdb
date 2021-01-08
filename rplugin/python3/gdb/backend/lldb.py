"""LLDB specifics."""

import json
import logging
import re
from gdb.backend import parser_impl
from gdb.backend import base


class _ParserImpl(parser_impl.ParserImpl):
    def __init__(self, common, handler):
        super().__init__(common, handler)

        re_prompt = re.compile(r'\s\(lldb\) $')
        self.add_trans(self.paused,
                       re.compile(r'Process \d+ resuming'),
                       self._paused_continue)
        self.add_trans(self.paused,
                       re.compile(r' at ([^:]+):(\d+)'),
                       self._paused_jump)
        self.add_trans(self.paused, re_prompt, self._query_b)
        self.add_trans(self.running,
                       re.compile(r'Process \d+ stopped'),
                       self._paused)
        self.add_trans(self.running, re_prompt, self._query_b)

        self.state = self.running


class _BreakpointImpl(base.BaseBreakpoint):
    def __init__(self, proxy):
        self.proxy = proxy
        self.logger = logging.getLogger("Gdb.Breakpoint")

    def query(self, fname: str):
        self.logger.info("Query breakpoints for %s", fname)
        resp = self.proxy.query(f"info-breakpoints {fname}\n")
        if not resp:
            return {}
        # LLDB may mess the input (like space + back space).
        start = resp.find('{')
        if start == -1:
            self.logger.warning("Couldn't find '{' in the reponse: %s", resp)
            return {}
        # We expect the proxies to send breakpoints for a given file
        # as a map of lines to array of breakpoint ids set in those lines.
        breaks = json.loads(resp[start:])
        err = breaks.get('_error', None)
        if err:
            # self.vim.command(f"echo \"Can't get breakpoints: {err}\"")
            return {}
        return breaks


class Lldb(base.BaseBackend):
    """LLDB parser and FSM."""

    def create_parser_impl(self, common, handler):
        """Create parser implementation instance."""
        return _ParserImpl(common, handler)

    def create_breakpoint_impl(self, proxy):
        """Create breakpoint implementation instance."""
        return _BreakpointImpl(proxy)

    command_map = {
        'delete_breakpoints': 'breakpoint delete',
        'breakpoint': 'b',
        'until {}': 'thread until {}',
    }

    def translate_command(self, command):
        """Adapt command if necessary."""
        return self.command_map.get(command, command)
