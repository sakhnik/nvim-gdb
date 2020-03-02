'''GDB specifics.'''

import os
import re
from gdb import parser
import logging


class Gdb:
    '''GDB parser and FSM.'''

    command_map = {
        'delete_breakpoints': 'delete',
        'breakpoint': 'break',
    }

    class Parser(parser.Parser):
        def __init__(self, common, cursor, win):
            super().__init__(common, cursor, win)

            re_prompt = re.compile(r'\x1a\x1a\x1a$')
            re_jump = re.compile(r'[\r\n]\x1a\x1a([^:]+):(\d+):\d+')
            self.add_trans(self.paused,
                           re.compile(r'[\r\n]Continuing\.'),
                           self._paused_continue)
            self.add_trans(self.paused, re_jump, self._paused_jump)
            self.add_trans(self.paused, re_prompt, self._query_b)
            self.add_trans(self.running,
                           re.compile(r'[\r\n]Breakpoint \d+'),
                           self._query_b)
            self.add_trans(self.running, re_prompt, self._query_b)
            self.add_trans(self.running, re_jump, self._paused_jump)

            self.state = self.running

    class Breakpoint:
        def __init__(self, proxy):
            self.proxy = proxy
            self.logger = logging.getLogger("Gdb.Breakpoint")

        def _ResolveFile(self, fname):
            '''Resolve full path to the filename into its presentation
               in the debugger.'''
            resp = self.proxy.query(f"handle-command info source {fname}")
            self.logger.debug(resp)
            pattern = re.compile(r"Current source file is ([^\r\n]+)")
            m = pattern.search(resp)
            if m:
                self.logger.info(m.group(1))
                return m.group(1)
            return fname

        def Query(self, fname):
            self.logger.info(f"Query breakpoints for {fname}")
            fname_sym = self._ResolveFile(fname)
            if fname != fname_sym:
                self.logger.info(f"Map file path {fname} to {fname_sym}")
            response = self.proxy.query("handle-command info breakpoints")
            if not response:
                return {}

            # Select lines in the current file with enabled breakpoints.
            pos_pattern = re.compile(r"([^:]+):(\d+)")
            enb_pattern = re.compile(r"\sy\s+0x")
            breaks = {}
            for line in response.splitlines():
                try:
                    if enb_pattern.search(line):    # Is enabled?
                        fields = re.split(r"\s+", line)
                        match = pos_pattern.fullmatch(fields[-1])   # file.cpp:line
                        if not match:
                            continue
                        is_end_match = fname_sym.endswith(match.group(1))
                        is_end_match_full_path = \
                            fname_sym.endswith(os.path.realpath(match.group(1)))
                        if (match and (is_end_match or is_end_match_full_path)):
                            line = match.group(2)
                            br_id = fields[0]
                            try:
                                breaks[line].append(br_id)
                            except KeyError:
                                breaks[line] = [br_id]
                except IndexError:
                    continue
                except ValueError as ex:
                    self.logger.exception('Exception')

            return breaks
