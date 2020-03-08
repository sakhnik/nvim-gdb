"""Base class for backends."""

import abc


class BaseBreakpoint(abc.ABC):
    """Abstract base class for breakpoint querying."""

    @abc.abstractmethod
    def query(self, fname: str):
        """Query actual breakpoints for the given file."""

    def dummy(self):
        """Treat the linter."""
