"""LLDB specifics."""

import json
import logging
import re
from gdb.backend import base
from typing import Optional, List, Any


class Lldb(base.BaseBackend):
    """LLDB parser and FSM."""

    command_map = {
        'delete_breakpoints': 'breakpoint delete',
        'breakpoint': 'b',
        'until {}': 'thread until {}',
        'info breakpoints': 'nvim-gdb-info-breakpoints',
    }

    def translate_command(self, command: str) -> str:
        """Adapt command if necessary."""
        return self.command_map.get(command, command)
