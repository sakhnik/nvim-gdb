'''LLDB specifics.'''

import re
from gdb import parser


class Lldb:
    '''LLDB parser and FSM.'''

    command_map = {
        'delete_breakpoints': 'breakpoint delete',
        'breakpoint': 'b',
        'until {}': 'thread until {}',
    }

    class Parser(parser.Parser):
        def __init__(self, common, cursor, win):
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
