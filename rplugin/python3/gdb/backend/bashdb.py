"""BashDB specifics."""

import re
import logging
from typing import Dict, List
from gdb.backend import parser_impl
from gdb.backend import base


class _ParserImpl(parser_impl.ParserImpl):
    def __init__(self, common, handler):
        super().__init__(common, handler)

        re_jump = re.compile(r'[\r\n]\(([^:]+):(\d+)\):(?=[\r\n])')
        re_prompt = re.compile(r'[\r\n]bashdb<\(?\d+\)?> $')
        re_term = re.compile(r'[\r\n]Debugged program terminated ')
        self.add_trans(self.paused, re_jump, self._paused_jump)
        self.add_trans(self.paused, re_term, self._handle_terminated)
        # Make sure the prompt is matched in the last turn to exhaust
        # every other possibility while parsing delayed.
        self.add_trans(self.paused, re_prompt, self._query_b)

        # Let's start the backend in the running state for the tests
        # to be able to determine when the launch finished.
        # It'll transition to the paused state once and will remain there.
        self.add_trans(self.running, re_jump, self._running_jump)
        self.add_trans(self.running, re_prompt, self._query_b)
        self.state = self.running

    def _running_jump(self, match):
        fname = match.group(1)
        line = match.group(2)
        self.logger.info("_running_jump %s:%s", fname, line)
        self.handler.jump_to_source(fname, int(line))
        return self.running

    def _handle_terminated(self, _):
        self.handler.continue_program()
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

    def create_parser_impl(self, common, handler):
        """Create parser implementation instance."""
        return _ParserImpl(common, handler)

    def create_breakpoint_impl(self, proxy):
        """Create breakpoint impl instance."""
        return _BreakpointImpl(proxy)

    command_map = {
        'delete_breakpoints': 'delete',
        'breakpoint': 'break',
        'info breakpoints': 'info breakpoints',
    }

    def translate_command(self, command):
        """Adapt command if necessary."""
        return self.command_map.get(command, command)

    def get_error_formats(self):
        """Return the list of errorformats for backtrace, breakpoints."""
        return ["%m\ in\ file\ `%f'\ at\ line\ %l%.%#",
                "%m\ called\ from\ file\ `%f'\ at\ line\ %l%.%#",
                "%m\ %f:%l%.%#"]

        # bashdb<18> bt
        # ->0 in file `main.sh' at line 8
        # ##1 Foo("1") called from file `main.sh' at line 18
        # ##2 Main() called from file `main.sh' at line 22
        # ##3 source("main.sh") called from file `/sbin/bashdb' at line 107
        # ##4 main("main.sh") called from file `/sbin/bashdb' at line 0
        # bashdb<22> info breakpoints
        # Num Type       Disp Enb What
        # 1   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:16
        #         breakpoint already hit 1 time
        # 2   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:7
        #         breakpoint already hit 1 time
        # 3   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:3
        # 4   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:8
