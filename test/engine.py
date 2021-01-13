"""Neovim abstraction for tests."""
import os
import time
import re
import threading
from pynvim import attach
from spy_ui import SpyUI


# Neovim proxy
class Engine:
    """Neovim engine."""

    def __init__(self):
        """Construct an engine."""
        addr = os.environ.get('NVIM_LISTEN_ADDRESS')
        if addr:
            self.nvim = attach('socket', path=addr)
        else:
            logfile = os.environ.get("ENGINE_LOG")
            if not logfile:
                logfile = "engine.log"
            self.screen = ""
            self.logf = open(logfile, "w")

            args = ["/usr/bin/env", "./nvim", "--embed", "--headless", "-n",
                    "--listen", "localhost:44444"]
            self.nvim = attach('child', argv=args)
            self.spy_ui = None
            self.t = threading.Thread(target=self.run_ui)
            self.t.start()
            # Dummy request to make sure the embedded Nvim proceeds
            # See in neovim bd8d43c6fef868 (startup: wait for embedder
            # before executing)
            self.eval("0")

        # Builds on GitHub seem to be more prone to races.
        is_github = os.environ.get('GITHUB_WORKFLOW')
        self.feed_delay = 0.02 if not is_github else 0.5
        self.launch_delay = 3000 if not is_github else 10000

    def close(self):
        '''Close.'''
        self.logf.close()
        self.logf = None
        self.spy_ui.close()
        try:
            self.nvim.command(":qa!")
        except:
            pass
        self.nvim.close()
        self.t.join()

    def log_screen(self):
        if not self.spy_ui:
            return
        screen = self.spy_ui.screen
        if screen != self.screen:
            self.screen = screen
            self.logf.write(screen)
            self.logf.write("\n")

    def log(self, msg):
        self.logf.write(msg)

    def run_ui(self):
        """Capture neovim UI."""
        self.spy_ui = SpyUI()
        self.spy_ui.run()

    def exe(self, cmd, delay=100):
        """Execute a Vim command."""
        self.log_screen()
        self.log(f"exe «{self._quote_keys(cmd)}»\n")
        self.nvim.command(cmd)
        time.sleep(delay * 0.001)
        self.log_screen()

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
        self.log_screen()
        self.log(f"feed «{self._quote_keys(keys)}»\n")
        self.nvim.input(keys)
        time.sleep(delay * 0.001)
        self.log_screen()

    def eval(self, expr):
        """Evaluate a Vim expression."""
        self.log_screen()
        self.log(f"eval «{expr}»\n")
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
    def wait_for(action, condition, deadline=2000):
        '''Wait until the action returns the expected value.'''
        deadline *= 0.001
        start = time.time()
        result = None
        while time.time() - start <= deadline:
            result = action()
            if condition(result):
                return None
            time.sleep(0.2)
        return result

    def wait_signs(self, expected, deadline=2000):
        '''Wait until signs are placed as expected.'''
        return self.wait_for(self.get_signs,
                lambda res: res == expected, deadline)

    def wait_paused(self):
        '''Wait until the parser FSM goes into the paused state.'''
        return self.wait_for(
            lambda: self.eval("GdbCall('parser.is_paused')"),
            lambda res: res, self.launch_delay)

    def _quote_keys(self, keys):
        return keys.replace('\n', '\\n').replace('\r', '\\r') \
            .replace('\t', '\\t').replace('\b', '\\b')
