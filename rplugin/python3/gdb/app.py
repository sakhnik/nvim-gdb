"""."""

import re
from typing import Union, Dict, Type

from gdb.common import Common


class App(Common):
    """Main application class."""

    def __init__(self, common, backendStr: str, proxyCmd: str,
                 clientCmd: str):
        """ctor."""
        super().__init__(common)
        self._last_command: Union[str, None] = None

        self.vim.exec_lua(f"nvimgdb.new('{backendStr}', '{proxyCmd}', '{clientCmd}')")
