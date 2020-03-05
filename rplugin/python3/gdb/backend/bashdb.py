'''BashDB specifics.'''

import re
from gdb import parser
import logging


class BashDB:
    '''BashDB FSM.'''

    command_map = {
        'delete_breakpoints': 'delete',
        'breakpoint': 'break',
    }

    class Parser(parser.Parser):
        def __init__(self, common, cursor, win):
            super().__init__(common, cursor, win)

            re_jump = re.compile(r'[\r\n]\(([^:]+):(\d+)\):(?=[\r\n])')
            re_prompt = re.compile(r'[\r\n]bashdb<\(?\d+\)?> $')
            re_term = re.compile(r'[\r\n]Debugged program terminated ')
            self.add_trans(self.paused, re_jump, self._paused_jump)
            self.add_trans(self.paused, re_prompt, self._query_b)
            self.add_trans(self.paused, re_term, self._handle_terminated)
            self.state = self.paused

        def _handle_terminated(self, _):
            self.cursor.hide()
            return self.paused


    class Breakpoint:
        def __init__(self, proxy):
            self.proxy = proxy
            self.logger = logging.getLogger("BashDB.Breakpoint")

        def query(self, fname):
            self.logger.info(f"Query breakpoints for {fname}")
            response = self.proxy.query("handle-command info breakpoints")
            if not response:
                return {}

            # Select lines in the current file with enabled breakpoints.
            pattern = re.compile(r"([^:]+):(\d+)")
            breaks = {}
            for line in response.splitlines():
                try:
                    fields = re.split(r"\s+", line)
                    if fields[3] == 'y':    # Is enabled?
                        match = pattern.fullmatch(fields[-1])   # file.cpp:line
                        if match and match.group(1) == fname:
                            line = match.group(2)
                            br_id = fields[0]
                            try:
                                breaks[line].append(br_id)
                            except KeyError:
                                breaks[line] = [br_id]
                except (ValueError, IndexError):
                    continue

            return breaks
