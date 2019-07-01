'''LLDB specifics.'''

import re
from gdb.scm import BaseScm


class LldbScm(BaseScm):
    '''LLDB SCM.'''
    def __init__(self, vim, logger, cursor, win):
        super().__init__(vim, logger, cursor, win)

        re_prompt = re.compile(r'[\r\n]\(lldb\) $')
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


def init():
    '''Initialize the backend.'''
    return {'initScm': LldbScm,
            'delete_breakpoints': 'breakpoint delete',
            'breakpoint': 'b',
            'until {}': 'thread until {}'}
