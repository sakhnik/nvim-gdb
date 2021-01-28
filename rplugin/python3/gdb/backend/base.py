"""Base class for backends."""

import abc
from typing import List


class BaseBackend(abc.ABC):
    """Abstract base class for a debugger backend."""

    def translate_command(self, command: str) -> str:
        """Adapt command for the debugger if necessary."""

    @staticmethod
    def llist_filter_breakpoints(locations):
        """Filter out service lines in the breakpoint list capture."""
        return locations
