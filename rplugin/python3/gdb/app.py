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

    def lopen(self, kind, mods):
        """Load backtrace or breakpoints into the location list."""
        cmd = ''
        if kind == "backtrace":
            cmd = self.vim.exec_lua("return nvimgdb.i().backend:translate_command('bt')")
        elif kind == "breakpoints":
            cmd = self.vim.exec_lua("return nvimgdb.i().backend:translate_command('info breakpoints')")
        else:
            self.logger.warning("Unknown lopen kind %s", kind)
            return
        self.vim.exec_lua(f"nvimgdb.i().win:lopen('{cmd}', '{kind}', '{mods}')")

    def get_for_llist(self, kind, cmd):
        output = self.vim.exec_lua(f"return nvimgdb.i():custom_command('{cmd}')")
        lines = re.split(r'[\r\n]+', output)
        if kind == "backtrace":
            return lines
        elif kind == "breakpoints":
            return lines
        else:
            self.logger.warning("Unknown lopen kind %s", kind)
