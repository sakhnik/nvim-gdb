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
        # Monotonously increasing processed byte counter
        self.byte_count = 1
        # Ordered byte counters to ensure parsing in the right order
        self.parsing_progress: List[int] = []

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

    def _paused(self, _):
        self.logger.info('_paused')
        return self.paused

    def _query_b(self, _):
        self.logger.info('_query_b')
        self.handler.query_breakpoints()
        return self.paused

    def feed(self, lines: List[str]):
        """Process a line of the debugger output through the FSM.

        It may be hard to guess when the backend started waiting for input,
        therefore parsing should be done asynchronously after a bit of delay.
        """
        for line in lines:
            self.logger.debug("'%s'", line)
            if line:
                self.buffer += line
                self.byte_count += len(line)
            else:
                self.buffer += '\n'
                self.byte_count += 1
        self.parsing_progress.append(self.byte_count)
        self.delay_parsing(self.byte_count)

    def delay_parsing(self, byte_count):
        # Unfortunately, we can't just use self.vim.loop.call_later()
        # because nvim won't execute commands from that context.
        # So it's necessary to use nvim's timers.
        cur_tab = self.vim.current.tabpage.handle
        handler = f"GdbParserDelayElapsed({cur_tab}, {byte_count})"
        self.vim.command(f"call timer_start(50, {{id -> {handler}}})")

    def _search(self, ignore_tail_bytes):
        if len(self.buffer) <= ignore_tail_bytes:
            return False
        # If there is a matcher matching the line, call its handler.
        for matcher, func in self.state:
            match = matcher.search(self.buffer)
            if match:
                if len(self.buffer) - match.end() < ignore_tail_bytes:
                    # Wait a bit longer, the next timer is pending
                    return False
                self.buffer = self.buffer[match.end():]
                self.logger.debug("prev state: %s", self._get_state_name())
                self.state = func(match)
                self.logger.info("new state: %s", self._get_state_name())
                return True
        return False

    def delay_elapsed(self, byte_count):
        if self.parsing_progress[0] != byte_count:
            # Another parsing is already in progress, return to this mark later
            self.delay_parsing(byte_count)
            return
        # Detect whether new input has been received before the previous
        # delay elapsed.
        ignore_tail_bytes = self.byte_count - byte_count
        while self._search(ignore_tail_bytes):
            pass
        # Pop the current mark allowing parsing the next chunk
        self.parsing_progress = self.parsing_progress[1:]
