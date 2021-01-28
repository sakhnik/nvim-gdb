"""GDB specifics."""

import logging
import os
import re
from typing import Dict, List
from gdb.backend import base



class Gdb(base.BaseBackend):
    """GDB parser and FSM."""

    command_map = {
        'delete_breakpoints': 'delete',
        'breakpoint': 'break',
        'info breakpoints': 'info breakpoints',
    }

    def translate_command(self, command: str) -> str:
        """Adapt command if necessary."""
        return self.command_map.get(command, command)

    @staticmethod
    def llist_filter_breakpoints(locations):
        """Filter out service lines in the breakpoint list capture."""
        return [s for s  in locations if not s.startswith("Num")]
