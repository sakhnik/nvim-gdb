"""State machine for handing debugger output."""

from typing import List, Tuple, Callable, Union
import re
from gdb.common import Common
from gdb.cursor import Cursor
from gdb.win import Win


class Parser(Common):
    """Common FSM implementation for the integrated backends."""

    # [(matcher, matchingFunc)]
    matcher_type = Union[re.Pattern]
    transition_type = Callable[[re.Match], None]
    state_list_type = List[Tuple[matcher_type, transition_type]]

    def __init__(self, common: Common, cursor: Cursor, win: Win):
        """ctor."""
        super().__init__(common)
        self.cursor = cursor
        self.win = win
        # The running state
        self.running: Parser.state_list_type = []
        # The paused state [(matcher, matchingFunc)]
        self.paused: Parser.state_list_type = []
        # Current state (either self.running or self.paused)
        self.state: Parser.state_list_type = self.paused
        self.buffer = '\n'

    @staticmethod
    def add_trans(state: state_list_type, matcher: matcher_type,
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
        self.cursor.hide()

        self.vim.command("doautocmd User NvimGdbContinue")

        return self.running

    def _paused_jump(self, match: re.Match):
        fname = match.group(1)
        line = match.group(2)
        self.logger.info("_paused_jump %s:%s", fname, line)
        self.win.jump(fname, int(line))

        self.vim.command("doautocmd User NvimGdbBreak")

        return self.paused

    def _query_b(self, _):
        self.logger.info('_query_b')
        self.win.query_breakpoints()

        # Execute the rest of custom commands
        self.vim.command("doautocmd User NvimGdbQuery")

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
