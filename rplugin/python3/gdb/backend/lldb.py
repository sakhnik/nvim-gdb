from gdb.scm import BaseScm
import re

#  lldb specifics

class LldbScm(BaseScm):
    def __init__(self, vim, logger, cursor, win):
        super().__init__(vim, logger, cursor, win)

        self.addTrans(self.paused,  re.compile(r'[\r\n]Process \d+ resuming'), self.pausedContinue)
        self.addTrans(self.paused,  re.compile(r' at ([^:]+):(\d+)'),      self.pausedJump)
        self.addTrans(self.paused,  re.compile(r'[\r\n]\(lldb\) $'),           self.queryB)
        self.addTrans(self.running, re.compile(r'[\r\n]Breakpoint \d+:'),      self.queryB)
        self.addTrans(self.running, re.compile(r'[\r\n]Process \d+ stopped'),  self.queryB)
        self.addTrans(self.running, re.compile(r'[\r\n]\(lldb\) $'),           self.queryB)

        self.state = self.running


def init():
    return { 'initScm': LldbScm,
             'delete_breakpoints': 'breakpoint delete',
             'breakpoint': 'b',
             'until {}': 'thread until {}' }
