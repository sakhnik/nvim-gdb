"""PDB specifics."""

from gdb.common import Common
from gdb.parser import ParserAdapter
from gdb.proxy import Proxy
import re
import logging
from typing import Dict, List
from gdb.backend import parser_impl
from gdb.backend import base


class _ParserImpl(parser_impl.ParserImpl):
    def __init__(self, common: Common, handler: ParserAdapter):
        super().__init__(common, handler)

        re_jump = re.compile(r'[\r\n ]> ([^(]+)\((\d+)\)[^(]+\(\)')
        re_prompt = re.compile(r'[\r\n]\(Pdb\+?\+?\) $')
        self.add_trans(self.paused, re_jump, self._paused_jump)
        self.add_trans(self.paused, re_prompt, self._query_b)

        # Let's start the backend in the running state for the tests
        # to be able to determine when the launch finished.
        # It'll transition to the paused state once and will remain there.
        self.add_trans(self.running, re_jump, self._running_jump)
        self.add_trans(self.running, re_prompt, self._query_b)
        self.state = self.running

    def _running_jump(self, match):
        fname = match.group(1)
        line = match.group(2)
        self.logger.info("_running_jump %s:%s", fname, line)
        self.handler.jump_to_source(fname, int(line))
        return self.running


class _BreakpointImpl(base.BaseBreakpoint):
    def __init__(self, proxy: Proxy):
        """ctor."""
        self.proxy = proxy
        self.logger = logging.getLogger("Pdb.Breakpoint")

    def query(self, fname: str):
        """Query actual breakpoints for the given file."""
        self.logger.info("Query breakpoints for %s", fname)

        response = self.proxy.query("handle-command break")

        # Num Type         Disp Enb   Where
        # 1   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:8

        breaks: Dict[str, List[str]] = {}
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


class Pdb(base.BaseBackend):
    """PDB parser and FSM."""

    def create_parser_impl(self, common: Common, handler: ParserAdapter):
        """Create parser implementation instance."""
        return _ParserImpl(common, handler)

    def create_breakpoint_impl(self, proxy: Proxy):
        """Create breakpoint implementation instance."""
        return _BreakpointImpl(proxy)

    command_map = {
        'delete_breakpoints': 'clear',
        'breakpoint': 'break',
        'finish': 'return',
        'print {}': 'print({})',
        'info breakpoints': 'break',
    }

    def translate_command(self, command):
        """Adapt command if necessary."""
        return self.command_map.get(command, command)

    def get_error_formats(self):
        """Return the list of errorformats for backtrace, breakpoints."""
        return ["%m\ at\ %f:%l", "%[>\ ]%#%f(%l)%m"]

        #(Pdb) break
        #Num Type         Disp Enb   Where
        #1   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:14
        #2   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:4
        #(Pdb) bt
        #  /usr/lib/python3.9/bdb.py(580)run()
        #-> exec(cmd, globals, locals)
        #  <string>(1)<module>()
        #  /tmp/nvim-gdb/test/main.py(22)<module>()
        #-> _main()
        #  /tmp/nvim-gdb/test/main.py(16)_main()
        #-> _foo(i)
        #  /tmp/nvim-gdb/test/main.py(11)_foo()
        #-> return num + _bar(num - 1)
        #> /tmp/nvim-gdb/test/main.py(5)_bar()

    @staticmethod
    def llist_filter_breakpoints(locations):
        """Filter out service lines in the breakpoint list capture."""
        return [s for s  in locations if not s.startswith("Num")]
