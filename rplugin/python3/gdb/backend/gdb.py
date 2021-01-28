"""GDB specifics."""

from gdb.parser import ParserAdapter
from gdb.common import Common
import logging
import os
import re
from typing import Dict, List
from gdb.backend import parser_impl
from gdb.backend import base


class _ParserImpl(parser_impl.ParserImpl):
    def __init__(self, common: Common, handler: ParserAdapter):
        super().__init__(common, handler)

        re_prompt = re.compile(r'\x1a\x1a\x1a$')
        re_jump = re.compile(r'[\r\n]\x1a\x1a([^:]+):(\d+):\d+')
        self.add_trans(self.paused,
                       re.compile(r'[\r\n]Continuing\.'),
                       self._paused_continue)
        self.add_trans(self.paused, re_jump, self._paused_jump)
        self.add_trans(self.paused, re_prompt, self._query_b)
        self.add_trans(self.running,
                       re.compile(r'[\r\n]Breakpoint \d+'),
                       self._query_b)
        self.add_trans(self.running, re_prompt, self._query_b)
        self.add_trans(self.running, re_jump, self._paused_jump)

        self.state = self.running


class Gdb(base.BaseBackend):
    """GDB parser and FSM."""

    def create_parser_impl(self, common: Common, handler: ParserAdapter):
        """Create parser implementation instance."""
        return _ParserImpl(common, handler)

    command_map = {
        'delete_breakpoints': 'delete',
        'breakpoint': 'break',
        'info breakpoints': 'info breakpoints',
    }

    def translate_command(self, command: str) -> str:
        """Adapt command if necessary."""
        return self.command_map.get(command, command)

    @staticmethod
    def llist_filter_breakpoints(locations):
        """Filter out service lines in the breakpoint list capture."""
        return [s for s  in locations if not s.startswith("Num")]
