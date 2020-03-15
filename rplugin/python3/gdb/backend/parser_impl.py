"""Base implementation for all parsers."""

import re
import sys
from typing import Any, List, Tuple, Callable, Union

from gdb.common import Common
from gdb.backend.base import BaseParser, ParserHandler


if sys.version_info >= (3, 7):
    MatcherType = Union[re.Pattern]
    MatchType = Union[re.Match]
else:
    MatcherType = Union[Any]
    MatchType = Union[Any]


class ParserImpl(Common, BaseParser):
    """Common FSM implementation for the integrated backends."""

    # [(matcher, matchingFunc)]
    transition_type = Callable[[MatchType], None]
    state_list_type = List[Tuple[MatcherType, transition_type]]

    def __init__(self, common: Common, handler: ParserHandler):
        """ctor."""
        super().__init__(common)
        self.handler = handler
        # The running state
        self.running: ParserImpl.state_list_type = []
        # The paused state [(matcher, matchingFunc)]
        self.paused: ParserImpl.state_list_type = []
        # Current state (either self.running or self.paused)
        self.state: ParserImpl.state_list_type = self.paused
        self.buffer = '\n'

    @staticmethod
    def add_trans(state: state_list_type, matcher: MatcherType,
                  func: transition_type):
        """Add a new transition for a given state."""
        state.append((matcher, func))

    def is_paused(self):
        """Test whether the FSM is in the paused state."""
        return self.state == self.paused

    def is_running(self):
        """Test whether the FSM is in the running state."""
        return self.state == self.running

    def _get_state_name(self):
        if self.state == self.running:
            return "running"
        if self.state == self.paused:
            return "paused"
        return str(self.state)

    def _paused_continue(self, _):
        self.logger.info("_paused_continue")
        self.handler.continue_program()
        return self.running

    def _paused_jump(self, match: MatchType):
        fname = match.group(1)
        line = match.group(2)
        self.logger.info("_paused_jump %s:%s", fname, line)
        self.handler.jump_to_source(fname, int(line))
        return self.paused

    def _query_b(self, _):
        self.logger.info('_query_b')
        self.handler.query_breakpoints()
        return self.paused

    def _search(self):
        # If there is a matcher matching the line, call its handler.
        for matcher, func in self.state:
            match = matcher.search(self.buffer)
            if match:
                self.buffer = self.buffer[match.end():]
                self.state = func(match)
                self.logger.info("new state: %s", self._get_state_name())
                return True
        return False

    def feed(self, lines: List[str]):
        """Process a line of the debugger output through the FSM."""
        for line in lines:
            self.logger.debug(line)
            if line:
                self.buffer += line
            else:
                self.buffer += '\n'
            while self._search():
                pass
