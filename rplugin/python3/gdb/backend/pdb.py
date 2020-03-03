'''PDB specifics.'''

import re
from gdb import parser
import logging


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


    class Breakpoint:
        def __init__(self, proxy):
            self.proxy = proxy
            self.logger = logging.getLogger("Pdb.Breakpoint")

        def Query(self, fname):
            self.logger.info(f"Query breakpoints for {fname}")

            response = self.proxy.query("handle-command break")

            # Num Type         Disp Enb   Where
            # 1   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:8

            breaks = {}
            for line in response.splitlines():
                try:
                    tokens = re.split(r'\s+', line)
                    bid = tokens[0]
                    if tokens[1] != 'breakpoint':
                        continue
                    if tokens[3] != 'yes':
                        continue
                    src_line = re.split(r':', tokens[-1])
                    if fname == src_line[0]:
                        try:
                            breaks[src_line[1]].append(bid)
                        except KeyError:
                            breaks[src_line[1]] = [bid]
                except (IndexError, ValueError):
                    continue

            return breaks
