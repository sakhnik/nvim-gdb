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
            args = ["/usr/bin/env", "nvim", "--embed", "--headless", "-n", "-u", "init.vim"]
            self.nvim = attach('child', argv=args)
            # Dummy request to make sure the embedded Nvim proceeds
            # See in neovim bd8d43c6fef868 (startup: wait for embedder before executing)
            self.Eval("0")

    def Exe(self, cmd, delay=0.1):
        """Execute a Vim command."""
        self.nvim.command(cmd)
        time.sleep(delay)

    def GetSigns(self):
        """Get pointer position and list of breakpoints."""

        out = self.nvim.eval('execute("sign place")')

        fname = ''     # Filename where the current line sign is
        curline = -1   # The line where the current line sign is
        cur = ''       # The return value from the function in the form fname:line
        for l in out.splitlines():
            m = re.match(r'Signs for ([^:]+):', l)
            if m:
                fname = os.path.basename(m.group(1))
                continue
            m = re.match(r'    line=(\d+)\s+id=\d+\s+name=GdbCurrentLine', l)
            if m:
                # There can be only one current line sign
                assert(curline == -1)
                curline = int(m.group(1))
                cur = "%s:%d" % (fname, curline)

        breaks = [int(l) for l
                  in re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbBreakpoint',
                                out)]
        return cur, sorted(breaks)

    def In(self, keys, delay=0.1):
        """Send a Vim keystroke to NeoVim."""
        self.nvim.input(keys)
        time.sleep(delay)

    def Ty(self, keys, delay=0.1):
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
