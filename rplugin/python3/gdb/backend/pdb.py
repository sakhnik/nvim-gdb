"""PDB specifics."""

from gdb.common import Common
from gdb.parser import ParserAdapter
import re
import logging
from typing import Dict, List
from gdb.backend import parser_impl
from gdb.backend import base


class _ParserImpl(parser_impl.ParserImpl):
    def __init__(self, common: Common, handler: ParserAdapter):
        super().__init__(common, handler)

        re_jump = re.compile(r'[\r\n ]> ([^(]+)\((\d+)\)[^(]+\(\)')
        re_prompt = re.compile(r'[\r\n]\(Pdb\+?\+?\) $')
        self.add_trans(self.paused, re_jump, self._paused_jump)
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


class Pdb(base.BaseBackend):
    """PDB parser and FSM."""

    def create_parser_impl(self, common: Common, handler: ParserAdapter):
        """Create parser implementation instance."""
        return _ParserImpl(common, handler)

    command_map = {
        'delete_breakpoints': 'clear',
        'breakpoint': 'break',
        'finish': 'return',
        'print {}': 'print({})',
        'info breakpoints': 'break',
    }

    def translate_command(self, command):
        """Adapt command if necessary."""
        return self.command_map.get(command, command)

    @staticmethod
    def llist_filter_breakpoints(locations):
        """Filter out service lines in the breakpoint list capture."""
        return [s for s  in locations if not s.startswith("Num")]
