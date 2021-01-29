"""BashDB specifics."""

import logging
import os
import re
from typing import Dict, List
from gdb.backend import base


class BashDB(base.BaseBackend):
    """BashDB FSM."""

    @staticmethod
    def llist_filter_breakpoints(locations):
        """Filter out service lines in the breakpoint list capture."""
        return [s for s  in locations if not s.startswith("Num")]
