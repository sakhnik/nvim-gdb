"""Neovim abstraction for tests."""
import os
import time
import re
from pynvim import attach


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
            self.eval("0")

    def close(self):
        self.nvim.close()

    def exe(self, cmd, delay=100):
        """Execute a Vim command."""
        self.nvim.command(cmd)
        time.sleep(delay * 0.001)

    def getSigns(self):
        """Get pointer position and list of breakpoints."""

        out = self.nvim.eval('execute("sign place")')

        fname = None   # Filename where the current line sign is
        cur = None     # The return value from the function in the form fname:line
        for l in out.splitlines():
            m = re.match(r'Signs for ([^:]+):', l)
            if m:
                fname = os.path.basename(m.group(1))
                continue
            m = re.match(r'    line=(\d+)\s+id=\d+\s+name=GdbCurrentLine', l)
            if m:
                # There can be only one current line sign
                assert(cur is None)
                cur = "%s:%s" % (fname, m.group(1))

        ret = {}
        if cur:
            ret["cur"] = cur
        br = {}
        for n in range(1, 11):
            lines = re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbBreakpoint' + str(n), out)
            lines = sorted([int(l) for l in lines])
            if lines:
                br[n] = lines
        if br:
            ret['break'] = br
        return ret

    def feed(self, keys, delay=100):
        """Send a Vim keystroke to NeoVim."""
        self.nvim.input(keys)
        time.sleep(delay * 0.001)

    def eval(self, expr):
        """Evaluate a Vim expression."""
        return self.nvim.eval(expr)

    def countBuffers(self):
        """Determine how many buffers are there."""
        self.eval('len(filter(range(bufnr("$") + 1), "buflisted(v:val)"))')
