"""LLDB specifics."""

import json
import logging
import re
from gdb.backend import parser_impl
from gdb.backend import base
from typing import Optional, List, Any


class _ParserImpl(parser_impl.ParserImpl):
    def __init__(self, common, handler):
        super().__init__(common, handler)

        re_prompt = re.compile(r'\s\(lldb\) \(lldb\) $')
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


class Lldb(base.BaseBackend):
    """LLDB parser and FSM."""

    def create_parser_impl(self, common, handler) -> parser_impl.ParserImpl:
        """Create parser implementation instance."""
        return _ParserImpl(common, handler)

    command_map = {
        'delete_breakpoints': 'breakpoint delete',
        'breakpoint': 'b',
        'until {}': 'thread until {}',
        'info breakpoints': 'nvim-gdb-info-breakpoints',
    }

    def translate_command(self, command: str) -> str:
        """Adapt command if necessary."""
        return self.command_map.get(command, command)
