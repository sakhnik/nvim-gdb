'''PDB specifics.'''

import re
from gdb.scm import BaseScm


class PdbScm(BaseScm):
    '''PDB SCM.'''
    def __init__(self, vim, logger, cursor, backend):
        super().__init__(vim, logger, cursor, backend)
        self.add_trans(self.paused,
                       re.compile(r'[\r\n]> ([^(]+)\((\d+)\)[^(]+\(\)'),
                       self._paused_jump)
        self.add_trans(self.paused,
                       re.compile(r'[\r\n]\(Pdb\) $'),
                       self._query_b)
        self.state = self.paused


def init():
    '''Initialize the backend.'''
    return {'initScm': PdbScm,
            'delete_breakpoints': 'clear',
            'breakpoint': 'break',
            'finish': 'return',
            'print {}': 'print({})'}
