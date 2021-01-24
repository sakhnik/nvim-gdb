"""GDB specifics."""

from gdb.proxy import Proxy
from gdb.parser import ParserAdapter
from gdb.common import Common
import logging
import os
import re
from typing import Dict, List
from gdb.backend import parser_impl
from gdb.backend import base


class _ParserImpl(parser_impl.ParserImpl):
    def __init__(self, common: Common, handler: ParserAdapter):
        super().__init__(common, handler)

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


class _BreakpointImpl(base.BaseBreakpoint):
    def __init__(self, proxy: Proxy):
        """ctor."""
        self.proxy = proxy
        self.logger = logging.getLogger("Gdb.Breakpoint")

    def query(self, fname: str) -> Dict[str, List[str]]:
        self.logger.info("Query breakpoints for %s", fname)
        response = self.proxy.query("handle-command info breakpoints")
        if not response:
            return {}
        return self._parse_response(response, fname)

    def _parse_response(self, response: str, fname_sym: str) -> Dict[str, List[str]]:
        # Select lines in the current file with enabled breakpoints.
        pos_pattern = re.compile(r"([^:]+):(\d+)")
        enb_pattern = re.compile(r"\sy\s+0x")
        breaks: Dict[str, List[str]] = {}
        for line in response.splitlines():
            try:
                if enb_pattern.search(line):    # Is enabled?
                    fields = re.split(r"\s+", line)
                    # file.cpp:line
                    match = pos_pattern.fullmatch(fields[-1])
                    if not match:
                        continue
                    is_end_match = fname_sym.endswith(match.group(1))
                    is_end_match_full_path = fname_sym.endswith(
                        os.path.realpath(match.group(1)))
                    if (match and
                            (is_end_match or is_end_match_full_path)):
                        line = match.group(2)
                        # If a breakpoint has multiple locations, GDB only
                        # allows to disable by the breakpoint number, not
                        # location number.  For instance, 1.4 -> 1
                        br_id = fields[0].split('.')[0]
                        try:
                            breaks[line].append(br_id)
                        except KeyError:
                            breaks[line] = [br_id]
            except IndexError:
                continue
            except ValueError:
                self.logger.exception('Exception')

        return breaks


class Gdb(base.BaseBackend):
    """GDB parser and FSM."""

    def create_parser_impl(self, common: Common, handler: ParserAdapter):
        """Create parser implementation instance."""
        return _ParserImpl(common, handler)

    def create_breakpoint_impl(self, proxy: Proxy):
        """Create breakpoint implementation instance."""
        return _BreakpointImpl(proxy)

    command_map = {
        'delete_breakpoints': 'delete',
        'breakpoint': 'break',
        'info breakpoints': 'info breakpoints',
    }

    def translate_command(self, command: str) -> str:
        """Adapt command if necessary."""
        return self.command_map.get(command, command)

    def get_error_formats(self):
        """Return the list of errorformats for backtrace, breakpoints."""
        return ["%m\ at\ %f:%l", "%m\ %f:%l"]

    @staticmethod
    def llist_filter_breakpoints(locations):
        """Filter out service lines in the breakpoint list capture."""
        return [s for s  in locations if not s.startswith("Num")]
