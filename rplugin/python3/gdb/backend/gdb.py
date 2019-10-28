'''GDB specifics.'''

import re

from gdb.parser import Parser
from gdb.common import Common
from gdb.cursor import Cursor
from gdb.win import Win


class GdbParser(Parser):
    '''GDB parser and FSM.'''

    def __init__(self, common: Common, cursor: Cursor, win: Win):
        super().__init__(common, cursor, win)

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

        self.command_map = {
            'delete_breakpoints': 'delete',
            'breakpoint': 'break',
            'frame': 'frame'
        }
