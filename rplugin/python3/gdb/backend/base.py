"""Base class for backends."""

import abc
from typing import List


class ParserHandler(abc.ABC):
    """The result of parsing."""

    @abc.abstractmethod
    def continue_program(self):
        """Handle the program continued execution. Hide the cursor."""

    @abc.abstractmethod
    def jump_to_source(self, fname: str, line: int):
        """Handle the program breaked. Show the source code."""

    @abc.abstractmethod
    def query_breakpoints(self):
        """It's high time to query actual breakpoints."""


class BaseParser(abc.ABC):
    """Abstract base class for parsing debugger output."""

    @abc.abstractmethod
    def is_paused(self) -> bool:
        """Test whether the FSM is in the paused state."""

    @abc.abstractmethod
    def is_running(self) -> bool:
        """Test whether the FSM is in the running state."""

    @abc.abstractmethod
    def feed(self, lines: List[str]) -> None:
        """Parse given lines."""


class BaseBreakpoint(abc.ABC):
    """Abstract base class for breakpoint querying."""

    @abc.abstractmethod
    def query(self, fname: str):
        """Query actual breakpoints for the given file."""

    def dummy(self):
        """Treat the linter."""


class BaseBackend(abc.ABC):
    """Abstract base class for a debugger backend."""

    @abc.abstractmethod
    def create_parser_impl(self, common, handler: ParserHandler) -> BaseParser:
        """Create a Parser implementation instance."""

    @abc.abstractmethod
    def create_breakpoint_impl(self, proxy) -> BaseBreakpoint:
        """Create a BaseBreakpoint implementation instance."""

    @abc.abstractmethod
    def translate_command(self, command: str) -> str:
        """Adapt command for the debugger if necessary."""

    @abc.abstractmethod
    def get_error_formats(self):
        """Return the list of errorformats for backtrace, breakpoints."""
