'''GDB specifics.'''

import re
from gdb import parser
import logging


class Gdb:
    '''GDB parser and FSM.'''

    logger = None

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

    @staticmethod
    def get_logger():
        if Gdb.logger is None:
            Gdb.logger = logging.getLogger("Gdb")
        return Gdb.logger

    @staticmethod
    def LocateSourceFile(fname, proxy):
        '''Resolve full path to the filename into its presentation
           in the debugger.'''
        resp = proxy.query(f"handle-command info source {fname}")
        Gdb.get_logger().debug(resp)
        pattern = re.compile(r"Current source file is ([^\r\n]+)")
        m = pattern.search(resp)
        if m:
            Gdb.get_logger().info(m.group(1))
            return m.group(1)
        return fname
