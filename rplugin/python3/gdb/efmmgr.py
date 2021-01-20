"""."""

from gdb.common import Common


class EfmMgr(Common):
    """Manager for the 'errorformat'."""

    def __init__(self, common):
        """Constructor."""
        super().__init__(common)
        self.counters = {}  # {efm: count}

    def cleanup(self):
        """Destructor."""
        for f in self.counters.keys():
            self.vim.command(f"set efm-={f}")

    def setup(self, formats):
        """Add 'efm' for some backend."""
        for f in formats:
            try:
                self.counters[f] += 1
            except KeyError:
                self.counters[f] = 1
                self.vim.command(f"set efm+={f}")

    def teardown(self, formats):
        """Remove 'efm' entries for some backend."""
        for f in formats:
            self.counters[f] -= 1
            if self.counters[f] < 1:
                del self.counters[f]
                self.vim.command(f"set efm-={f}")
