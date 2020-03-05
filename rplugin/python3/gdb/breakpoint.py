"""."""

from typing import Dict, List
from gdb.common import Common
from gdb.proxy import Proxy
from gdb.backend.gdb import Gdb


class Breakpoint(Common):
    """Handle breakpoint signs."""

    def __init__(self, common: Common, proxy: Proxy, backend: Gdb):
        """ctor."""
        super().__init__(common)
        self.proxy = proxy
        self.backend = backend
        # Discovered breakpoints so far: {file -> {line -> [id]}}
        self.breaks: Dict[str, Dict[str, List[str]]] = {}
        self.max_sign_id = 0

        # Backend class to query breakpoints
        self.impl = self.backend.Breakpoint(self.proxy)

    def clear_signs(self):
        """Clear all breakpoint signs."""
        for i in range(5000, self.max_sign_id + 1):
            self.vim.call('sign_unplace', 'NvimGdb', {'id': i})
        self.max_sign_id = 0

    def _set_signs(self, buf: int):
        if buf != -1:
            sign_id = 5000 - 1
            # Breakpoints need full path to the buffer (at least in lldb)
            bpath = self.vim.call("expand", f'#{buf}:p')

            def _get_sign_name(count):
                max_count = len(self.config.get('sign_breakpoint'))
                idx = count if count < max_count else max_count - 1
                return f"GdbBreakpoint{idx}"

            for line, ids in self.breaks.get(bpath, {}).items():
                sign_id += 1
                sign_name = _get_sign_name(len(ids))
                self.vim.call('sign_place', sign_id, 'NvimGdb', sign_name, buf,
                              {'lnum': line, 'priority': 10})
            self.max_sign_id = sign_id

    def query(self, buf_num: int, fname: str):
        """Query actual breakpoints for the given file."""
        self.logger.info("Query breakpoints for %s", fname)
        self.breaks[fname] = self.impl.query(fname)
        self.clear_signs()
        self._set_signs(buf_num)

    def reset_signs(self):
        """Reset all known breakpoints and their signs."""
        self.breaks = {}
        self.clear_signs()

    def get_for_file(self, fname: str, line: int):
        """Get breakpoints for the given position in a file."""
        breaks = self.breaks.get(fname, {})
        return breaks.get(f"{line}", {})   # make sure the line is a string
