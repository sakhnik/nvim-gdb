"""Neovim abstraction for tests."""
import os
import time
import re
from neovim import attach


# Neovim proxy
class Engine:
    """Neovim engine."""

    def __init__(self):
        """Construct an engine."""
        addr = os.environ.get('NVIM_LISTEN_ADDRESS')
        if addr:
            self.nvim = attach('socket', path=addr)
        else:
            args = ["/usr/bin/env", "nvim", "--embed", "-n", "-u", "init.vim"]
            self.nvim = attach('child', argv=args)

    def Command(self, cmd, delay=0.1):
        """Execute a Vim command."""
        self.nvim.command(cmd)
        time.sleep(delay)

    def GetSigns(self):
        """Get pointer position and list of breakpoints."""
        out = self.nvim.eval('execute("sign place")')
        curline = [int(l) for l in
                   re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbCurrentLine',
                              out)]
        assert(len(curline) <= 1)
        breaks = [int(l) for l
                  in re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbBreakpoint',
                                out)]
        return (curline[0] if curline else -1), sorted(breaks)

    def KeyStrokeL(self, keys, delay=0.1):
        """Send a Vim keystroke to NeoVim."""
        self.nvim.input(keys)
        time.sleep(delay)

    def KeyStroke(self, keys, delay=0.1):
        """Send a string to NeoVim as if typed."""
        self.nvim.feedkeys(keys, 't')
        time.sleep(delay)

    def Eval(self, expr):
        """Evaluate a Vim expression."""
        return self.nvim.eval(expr)

    def CountBuffers(self):
        """Determine how many buffers are there."""
        return sum(self.Eval('buflisted(%d)' % (i+1))
                   for i in range(0, self.Eval('bufnr("$")')))
