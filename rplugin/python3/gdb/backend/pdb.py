'''PDB specifics.'''

import re
from gdb.parser import Parser


class PdbParser(Parser):
    '''PDB parser and FSM.'''
    def __init__(self, common, cursor, backend):
        super().__init__(common, cursor, backend)
        self.add_trans(self.paused,
                       re.compile(r'[\r\n]> ([^(]+)\((\d+)\)[^(]+\(\)'),
                       self._paused_jump)
        self.add_trans(self.paused,
                       re.compile(r'[\r\n]\(Pdb\) $'),
                       self._query_b)
        self.state = self.paused


def init():
    '''Initialize the backend.'''
    return {'initParser': PdbParser,
            'delete_breakpoints': 'clear',
            'breakpoint': 'break',
            'finish': 'return',
            'print {}': 'print({})'}
