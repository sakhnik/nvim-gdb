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
            args = ["/usr/bin/env", "./nvim", "--embed", "--headless", "-n"]
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

        ret = {}

        for bnum in self.eval('nvim_list_bufs()'):
            out = self.eval(f'sign_getplaced({bnum}, {{"group": "NvimGdb"}})')
            breaks = {}
            for bsigns in out:
                for signs in bsigns['signs']:
                    sname = signs['name']
                    if sname == 'GdbCurrentLine':
                        bname = os.path.basename(self.eval(f"bufname({bnum})"))
                        assert "cur" not in ret
                        ret["cur"] = f'{bname}:{signs["lnum"]}'
                    if sname.startswith('GdbBreakpoint'):
                        num = int(sname[len('GdbBreakpoint'):])
                        try:
                            breaks[num].append(signs["lnum"])
                        except KeyError:
                            breaks[num] = [signs["lnum"]]
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
        self.eval('len(filter(nvim_list_bufs(), "nvim_buf_is_loaded(v:val)"))')

    def count_termbuffers(self):
        """Determine how many terminal buffers are there."""
        terms = [b for b in self.nvim.buffers \
                if b.api.is_loaded() and b.api.get_option('buftype') == 'terminal']
        return len(terms)

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

    def wait_signs(self, expected, deadline=2000):
        '''Wait until signs are placed as expected.'''
        return self.wait_equal(self.get_signs, expected, deadline)

    def wait_paused(self, deadline=3000):
        '''Wait until the parser FSM goes into the paused state.'''
        return self.wait_equal(
            lambda: self.eval("GdbCall('parser.is_paused')"),
            True, deadline)
