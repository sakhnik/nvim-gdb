'''PDB specifics.'''

import re
from gdb import parser


class Pdb:
    '''PDB parser and FSM.'''

    command_map = {
        'delete_breakpoints': 'clear',
        'breakpoint': 'break',
        'finish': 'return',
        'print {}': 'print({})',
    }

    class Parser(parser.Parser):
        def __init__(self, common, cursor, backend):
            super().__init__(common, cursor, backend)
            self.add_trans(self.paused,
                           re.compile(r'[\r\n]> ([^(]+)\((\d+)\)[^(]+\(\)'),
                           self._paused_jump)
            self.add_trans(self.paused,
                           re.compile(r'[\r\n]\(Pdb\) $'),
                           self._query_b)
            self.state = self.paused
