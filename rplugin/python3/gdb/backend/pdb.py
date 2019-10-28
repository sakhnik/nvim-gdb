'''PDB specifics.'''

import re

from gdb.common import Common
from gdb.cursor import Cursor
from gdb.parser import Parser
from gdb.win import Win


class PdbParser(Parser):
    '''PDB parser and FSM.'''

    def __init__(self, common: Common, cursor: Cursor, win: Win):
        super().__init__(common, cursor, win)
        self.add_trans(self.paused,
                       re.compile(r'[\r\n]> ([^(]+)\((\d+)\)[^(]+\(\)'),
                       self._paused_jump)
        self.add_trans(self.paused,
                       re.compile(r'[\r\n]\(Pdb\) $'),
                       self._query_b)
        self.state = self.paused

        self.command_map = {
            'delete_breakpoints': 'clear',
            'breakpoint': 'break',
            'finish': 'return',
            'print {}': 'print({})',
            'frame': 'list .'
        }
