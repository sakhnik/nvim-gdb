"""PDB specifics."""

from gdb.common import Common
import re
import logging
from typing import Dict, List
from gdb.backend import base



class Pdb(base.BaseBackend):
    """PDB parser and FSM."""

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

    @staticmethod
    def llist_filter_breakpoints(locations):
        """Filter out service lines in the breakpoint list capture."""
        return [s for s  in locations if not s.startswith("Num")]
