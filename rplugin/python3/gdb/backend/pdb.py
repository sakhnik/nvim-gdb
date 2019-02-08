from gdb.scm import BaseScm
import re

# pdb specifics

class PdbScm(BaseScm):
    def __init__(self, vim, cursor, backend):
        super().__init__(vim, cursor, backend)
        self.addTrans(self.paused, re.compile(r'^> ([^(]+)\((\d+)\)[^(]+\(\)'), self.pausedJump)
        self.addTrans(self.paused, re.compile(r'^\(Pdb\) $'),                   self.queryB)
        self.state = self.paused

def init():
    return { 'initScm': PdbScm,
             'delete_breakpoints': 'clear',
             'breakpoint': 'break',
             'finish': 'return',
             'print %s': 'print(%s)' }
