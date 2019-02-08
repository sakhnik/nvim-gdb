from gdb.scm import BaseScm
import re

# gdb specifics

class GdbScm(BaseScm):

    def __init__(self, vim, cursor, win):
        super().__init__(vim, cursor, win)

        self.addTrans(self.paused,  re.compile(r'^Continuing\.'),              self.pausedContinue)
        self.addTrans(self.paused,  re.compile(r'^\x1a\x1a([^:]+):(\d+):\d+'), self.pausedJump)
        self.addTrans(self.paused,  re.compile(r'^\(gdb\) $'),                 self.queryB)
        self.addTrans(self.running, re.compile(r'^Breakpoint \d+'),            self.queryB)
        self.addTrans(self.running, re.compile(r' hit Breakpoint \d+'),        self.queryB)
        self.addTrans(self.running, re.compile(r'^\(gdb\) $'),                 self.queryB)

        self.state = self.running


def init():
    return { 'initScm': GdbScm,
             'delete_breakpoints': 'delete',
             'breakpoint': 'break' }
