from gdb.scm import BaseScm
import re

# gdb specifics

class BashDBScm(BaseScm):

    def __init__(self, vim, logger, cursor, win):
        super().__init__(vim, logger, cursor, win)

        re_jump = re.compile(r'[\r\n]\(([^:]+):(\d+)\):(?=[\r\n])')
        re_prompt = re.compile(r'[\r\n]bashdb<\(?\d+\)?> $')
        re_term = re.compile(r'[\r\n]Debugged program terminated ')
        self.addTrans(self.paused,  re_jump,    self.pausedJump)
        self.addTrans(self.paused,  re_prompt,  self.queryB)
        self.addTrans(self.paused,  re_term,    self.handleTerminated)
        self.state = self.paused

    def handleTerminated(self, match):
        self.cursor.hide()
        return self.paused


def init():
    return { 'initScm': BashDBScm,
             'delete_breakpoints': 'delete',
             'breakpoint': 'break' }
