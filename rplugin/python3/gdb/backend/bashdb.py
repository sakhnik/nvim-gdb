from gdb.scm import BaseScm
import re

# gdb specifics

class BashDBScm(BaseScm):

    def __init__(self, vim, logger, cursor, win):
        super().__init__(vim, logger, cursor, win)

        re_jump = re.compile(r'[\r\n]\(([^:]+):(\d+)\):(?=[\r\n])')
        re_prompt = re.compile(r'[\r\n]bashdb<\(?\d+\)?> $')
        self.addTrans(self.paused,  re_jump,                             self.pausedJump)
        self.addTrans(self.paused,  re_prompt,                           self.queryB)
        self.state = self.paused


def init():
    return { 'initScm': BashDBScm,
             'delete_breakpoints': 'delete',
             'breakpoint': 'break' }
