"""PDB specifics."""

from gdb.common import Common
import re
import logging
from typing import Dict, List
from gdb.backend import base



class Pdb(base.BaseBackend):
    """PDB parser and FSM."""

    @staticmethod
    def llist_filter_breakpoints(locations):
        """Filter out service lines in the breakpoint list capture."""
        return [s for s  in locations if not s.startswith("Num")]
