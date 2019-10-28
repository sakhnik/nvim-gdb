'''LLDB specifics.'''

import re
from gdb.parser import Parser
from gdb.common import Common
from gdb.cursor import Cursor
from gdb.win import Win


class LldbParser(Parser):
    '''LLDB parser and FSM.'''

    def __init__(self, common: Common, cursor: Cursor, win: Win):
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

        self.command_map = {
            'initParser': LldbParser,
            'delete_breakpoints': 'breakpoint delete',
            'breakpoint': 'b',
            'until {}': 'thread until {}',
            'frame' : 'frame select'
        }
