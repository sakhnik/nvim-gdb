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
            args = ["/usr/bin/env", "nvim", "--embed", "--headless", "-n",
                    "-u", "init.vim"]
            self.nvim = attach('child', argv=args)
            # Dummy request to make sure the embedded Nvim proceeds
            # See in neovim bd8d43c6fef868 (startup: wait for embedder
            # before executing)
            self.eval("0")

        # Trusty builds on Travis seem to be more prone to races.
        self.feed_delay = 0.02 if not os.environ.get('TRAVIS') else 0.1

    def close(self):
        '''Close.'''
        self.nvim.close()

    def exe(self, cmd, delay=100):
        """Execute a Vim command."""
        self.nvim.command(cmd)
        time.sleep(delay * 0.001)

    def get_signs(self):
        """Get pointer position and list of breakpoints."""

        out = self.nvim.eval('execute("sign place group=NvimGdb")')

        fname = None   # Filename where the current line sign is
        cur = None  # The return value from the function in the form fname:line
        for line in out.splitlines():
            match = re.match(r'Signs for ([^:]+):', line)
            if match:
                fname = os.path.basename(match.group(1))
                continue
            match = re.match(r'    line=(\d+)\s+id=\d+\s+group=NvimGdb\s+name=GdbCurrentLine\s+priority=20',
                             line)
            if match:
                # There can be only one current line sign
                assert cur is None
                cur = "%s:%s" % (fname, match.group(1))

        ret = {}
        if cur:
            ret["cur"] = cur
        breaks = {}
        for num in range(1, 11):
            lines = re.findall(
                r'line=(\d+)\s+id=\d+\s+group=NvimGdb\s+name=GdbBreakpoint' + str(num),
                out)
            lines = sorted([int(l) for l in lines])
            if lines:
                breaks[num] = lines
        if breaks:
            ret['break'] = breaks
        return ret

    def feed(self, keys, delay=100):
        """Send a Vim keystroke to NeoVim."""
        time.sleep(self.feed_delay)
        self.nvim.input(keys)
        time.sleep(delay * 0.001)

    def eval(self, expr):
        """Evaluate a Vim expression."""
        return self.nvim.eval(expr)

    def count_buffers(self):
        """Determine how many buffers are there."""
        self.eval('len(filter(range(bufnr("$") + 1), "buflisted(v:val)"))')

    @staticmethod
    def wait_equal(action, expected, deadline=0):
        '''Wait until the action returns the expected value.'''
        deadline *= 0.001
        start = time.time()
        result = None
        while time.time() - start <= deadline:
            result = action()
            if result == expected:
                return None
            time.sleep(0.1)
        return result

    def wait_signs(self, expected, deadline=1000):
        '''Wait until signs are placed as expected.'''
        return self.wait_equal(self.get_signs, expected, deadline)

    def wait_paused(self, deadline=2000):
        '''Wait until the parser FSM goes into the paused state.'''
        return self.wait_equal(
            lambda: self.eval("GdbCall('parser.is_paused')"),
            True, deadline)
