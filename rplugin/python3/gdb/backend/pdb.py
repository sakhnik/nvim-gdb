from gdb.scm import BaseScm
import re

# pdb specifics

class PdbScm(BaseScm):
    def __init__(self, vim, logger, cursor, backend):
        super().__init__(vim, logger, cursor, backend)
        self.add_trans(self.paused, re.compile(r'[\r\n]> ([^(]+)\((\d+)\)[^(]+\(\)'), self._paused_jump)
        self.add_trans(self.paused, re.compile(r'[\r\n]\(Pdb\) $'),                   self._query_b)
        self.state = self.paused

def init():
    return { 'initScm': PdbScm,
             'delete_breakpoints': 'clear',
             'breakpoint': 'break',
             'finish': 'return',
             'print {}': 'print({})' }
