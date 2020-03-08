"""Base class for backends."""

import abc
from typing import List


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
    def create_parser_impl(self, common, cursor, win) -> BaseParser:
        """Create a Parser implementation instance."""

    @abc.abstractmethod
    def create_breakpoint_impl(self, proxy) -> BaseBreakpoint:
        """Create a BaseBreakpoint implementation instance."""
