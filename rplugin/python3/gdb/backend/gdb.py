from gdb.scm import BaseScm
import re

# gdb specifics

class GdbScm(BaseScm):

    def __init__(self, vim, logger, cursor, win):
        super().__init__(vim, logger, cursor, win)

        re_jump = re.compile(r'^\x1a\x1a([^:]+):(\d+):\d+')
        self.addTrans(self.paused,  re.compile(r'^Continuing\.'),       self.pausedContinue)
        self.addTrans(self.paused,  re_jump,                            self.pausedJump)
        self.addTrans(self.paused,  re.compile(r'^\(gdb\) $'),          self.queryB)
        self.addTrans(self.running, re.compile(r'^Breakpoint \d+'),     self.queryB)
        self.addTrans(self.running, re.compile(r'^\(gdb\) $'),          self.queryB)
        self.addTrans(self.running, re_jump,                            self.pausedJump)

        self.state = self.running


def init():
    return { 'initScm': GdbScm,
             'delete_breakpoints': 'delete',
             'breakpoint': 'break' }
