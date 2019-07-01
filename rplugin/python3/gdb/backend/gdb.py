'''GDB specifics.'''

import re
from gdb.scm import BaseScm


class GdbScm(BaseScm):
    '''GDB SCM.'''

    def __init__(self, vim, logger, cursor, win):
        super().__init__(vim, logger, cursor, win)

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


def init():
    '''Initialize the backend.'''
    return {'initScm': GdbScm,
            'delete_breakpoints': 'delete',
            'breakpoint': 'break'}
