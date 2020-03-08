"""BashDB specifics."""

import re
import logging
from typing import Dict, List
from gdb import parser
from gdb.backend import base


class _ParserImpl(parser.Parser):
    def __init__(self, common, cursor, win):
        super().__init__(common, cursor, win)

        re_jump = re.compile(r'[\r\n]\(([^:]+):(\d+)\):(?=[\r\n])')
        re_prompt = re.compile(r'[\r\n]bashdb<\(?\d+\)?> $')
        re_term = re.compile(r'[\r\n]Debugged program terminated ')
        self.add_trans(self.paused, re_jump, self._paused_jump)
        self.add_trans(self.paused, re_prompt, self._query_b)
        self.add_trans(self.paused, re_term, self._handle_terminated)
        self.state = self.paused

    def _handle_terminated(self, _):
        self.cursor.hide()
        return self.paused


class _BreakpointImpl(base.BaseBreakpoint):
    def __init__(self, proxy):
        self.proxy = proxy
        self.logger = logging.getLogger("BashDB.Breakpoint")

    def query(self, fname: str):
        self.logger.info("Query breakpoints for %s", fname)
        response = self.proxy.query("handle-command info breakpoints")
        if not response:
            return {}

        # Select lines in the current file with enabled breakpoints.
        pattern = re.compile(r"([^:]+):(\d+)")
        breaks: Dict[str, List[str]] = {}
        for line in response.splitlines():
            try:
                fields = re.split(r"\s+", line)
                if fields[3] == 'y':    # Is enabled?
                    match = pattern.fullmatch(fields[-1])   # file.cpp:line
                    if match and match.group(1) == fname:
                        line = match.group(2)
                        br_id = fields[0]
                        try:
                            breaks[line].append(br_id)
                        except KeyError:
                            breaks[line] = [br_id]
            except (ValueError, IndexError):
                continue

        return breaks


class BashDB(base.BaseBackend):
    """BashDB FSM."""

    def create_parser_impl(self, common, cursor, win):
        """Create parser implementation instance."""
        return _ParserImpl(common, cursor, win)

    def create_breakpoint_impl(self, proxy):
        """Create breakpoint impl instance."""
        return _BreakpointImpl(proxy)

    command_map = {
        'delete_breakpoints': 'delete',
        'breakpoint': 'break',
    }

    def translate_command(self, command):
        """Adapt command if necessary."""
        return self.command_map.get(command, command)
