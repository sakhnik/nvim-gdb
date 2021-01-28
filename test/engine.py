"""Neovim abstraction for tests."""

import logging
import os
import threading
import time
from pynvim import attach
from spy_ui import SpyUI


# Neovim proxy
class Engine:
    """Neovim engine."""

    def __init__(self):
        """Construct an engine."""
        self.logger = logging.getLogger("Engine")
        self.logger.setLevel(logging.DEBUG)
        lhandl = logging.NullHandler() if not os.environ.get('CI') \
            else logging.FileHandler("engine.log")
        fmt = "%(asctime)s [%(levelname)s]: %(message)s"
        lhandl.setFormatter(logging.Formatter(fmt))
        self.logger.addHandler(lhandl)

        self.logger.info("Starting test nvim engine")

        self.screen = ""

        args = ["/usr/bin/env", "./nvim", "--embed", "--headless", "-n",
                "--listen", "localhost:44444"]
        self.nvim = attach('child', argv=args)
        self.spy_ui = None
        self.thrd = threading.Thread(target=self.run_ui)
        self.thrd.start()
        # Dummy request to make sure the embedded Nvim proceeds
        # See in neovim bd8d43c6fef868 (startup: wait for embedder
        # before executing)
        self.eval("0")

        # Builds on GitHub seem to be more prone to races.
        is_github = os.environ.get('GITHUB_WORKFLOW')
        self.feed_delay = 0.02 if not is_github else 0.5
        self.launch_delay = 3000 if not is_github else 20000

    def close(self):
        '''Close.'''
        self.spy_ui.close()
        try:
            self.nvim.command(":qa!")
        except OSError:
            pass
        self.nvim.close()
        self.thrd.join()

    def log_screen(self):
        """Log the current Spy UI screen if it has changed."""
        if not self.spy_ui:
            return
        screen = self.spy_ui.screen
        if screen != self.screen:
            self.screen = screen
            self.logger.info("\n%s", screen)

    def run_ui(self):
        """Capture neovim UI."""
        self.spy_ui = SpyUI()
        self.spy_ui.run()

    def exe(self, cmd, delay=100):
        """Execute a Vim command."""
        self.log_screen()
        self.logger.info("exe «%s»", self._quote_keys(cmd))
        self.nvim.command(cmd)
        time.sleep(delay * 0.001)
        self.log_screen()

    def get_signs(self):
        """Get pointer position and list of breakpoints."""

        ret = {}

        for buf in self.nvim.buffers:
            if not buf.valid or not self.nvim.api.buf_is_loaded(buf.handle):
                continue
            out = self.eval(f'sign_getplaced({buf.number}, {{"group": "NvimGdb"}})')
            breaks = {}
            for bsigns in out:
                for signs in bsigns['signs']:
                    sname = signs['name']
                    if sname == 'GdbCurrentLine':
                        bname = os.path.basename(buf.name)
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
        self.logger.info("feed «%s»", self._quote_keys(keys))
        self.nvim.input(keys)
        time.sleep(delay * 0.001)
        self.log_screen()

    def eval(self, expr):
        """Evaluate a Vim expression."""
        self.log_screen()
        self.logger.info("eval «%s»", expr)
        return self.nvim.eval(expr)

    def exec_lua(self, expr):
        """Execute lua statement."""
        self.log_screen()
        self.logger.info("exec_lua «%s»", expr)
        return self.nvim.exec_lua(expr)

    def count_buffers(self):
        """Determine how many buffers are there."""
        self.eval('len(filter(nvim_list_bufs(), "nvim_buf_is_loaded(v:val)"))')

    def count_termbuffers(self):
        """Determine how many terminal buffers are there."""
        terms = [b for b in self.nvim.buffers
                 if b.api.is_loaded() and
                 b.api.get_option('buftype') == 'terminal']
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
            lambda: self.exec_lua("return nvimgdb.i().parser:is_paused()"),
            lambda res: res, self.launch_delay)

    @staticmethod
    def _quote_keys(keys):
        return keys.replace('\n', '\\n').replace('\r', '\\r') \
            .replace('\t', '\\t').replace('\b', '\\b')
