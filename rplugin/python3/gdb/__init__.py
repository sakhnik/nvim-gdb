"""Plugin entry point."""

# pylint: disable=broad-except
import re
from contextlib import contextmanager
import logging
import logging.config
from typing import Dict
import pynvim   # type: ignore
from gdb.common import BaseCommon, Common
from gdb.app import App
from gdb.logger import LOGGING_CONFIG


@pynvim.plugin
class Gdb(Common):
    """Plugin implementation."""

    def __init__(self, vim):
        """ctor."""
        logging.config.dictConfig(LOGGING_CONFIG)
        common = BaseCommon(vim)
        super().__init__(common)
        self.apps: Dict[int, App] = {}
        self.ansi_escaper = re.compile(r'\x1B[@-_][0-?]*[ -/]*[@-~]')

    def _get_app(self) -> int:
        return self.apps.get(self.vim.current.tabpage.handle, None)

    @pynvim.function('GdbInit', sync=True)
    def gdb_init(self, args):
        """Handle the command GdbInit."""
        # Prepare configuration: keymaps, hooks, parameters etc.
        common = BaseCommon(self.vim)
        if not self.apps:
            self.vim.exec_lua("nvimgdb = require'nvimgdb'")

        app = App(common, *args)
        self.apps[self.vim.current.tabpage.handle] = app
        self.vim.exec_lua("nvimgdb.i():start()")
        if len(self.apps) == 1:
            # Initialize the UI commands, autocommands etc
            self.vim.call("nvimgdb#GlobalInit")

    @contextmanager
    def _saved_hidden(self):
        # Prevent "ghost" [noname] buffers when leaving the debugger
        # and 'hidden' is on
        hidden = self.vim.eval("&hidden")
        if hidden:
            self.vim.command("set nohidden")
        yield
        # sets hidden back to user default
        if hidden:
            self.vim.command("set hidden")

    @pynvim.function('GdbCleanup', sync=True)
    def gdb_cleanup(self, args):
        """Handle the command GdbCleanup."""
        tab = int(args[0])
        self.logger.info("Cleanup tab=%d", tab)
        try:
            app = self.apps.pop(tab, None)
            if app:
                with self._saved_hidden():
                    if len(self.apps) == 0:
                        # Cleanup commands, autocommands etc
                        self.vim.call("nvimgdb#GlobalCleanup")
                    self.vim.exec_lua(f"nvimgdb.cleanup({tab})")
                # TabEnter isn't fired automatically when a tab is closed
                self.gdb_handle_event(["on_tab_enter"])
        except Exception:
            self.logger.exception("FIXME GdbCleanup Exception")

    @pynvim.function('GdbHandleEvent', sync=True)
    def gdb_handle_event(self, args):
        """Handle the command GdbHandleEvent."""
        self.logger.info("GdbHandleEvent %s", ' '.join(args))
        try:
            app = self._get_app()
            if app:
                handler = getattr(app, args[0])
                handler()
        except Exception:
            self.logger.exception("GdbHandleEvent Exception")

    @pynvim.function('GdbHandleTabClosed', sync=True)
    def gdb_handle_tab_closed(self, _):
        """Handle the function GdbHandleTabClosed."""
        self.logger.info("GdbHandleTabClosed")
        active_tabs = {t.handle for t in self.vim.tabpages}
        managed_tabs = {t for t, _ in self.apps.items()}
        closed_tabs = managed_tabs.difference(active_tabs)
        for tab in closed_tabs:
            self.gdb_cleanup([tab])

    @pynvim.function('GdbHandleVimLeavePre', sync=True)
    def gdb_handle_vim_leave_pre(self, _):
        """Handle function GdbHandleVimLeavePre."""
        self.logger.info("GdbHandleVimLeavePre")
        # Make sure a copy of the list is made.
        for tab in [t for t, _ in self.apps.items()]:
            self.gdb_cleanup([tab])

    @pynvim.function('GdbBreakpointToggle', sync=True)
    def gdb_breakpoint_toggle(self, _):
        """Handle command GdbBreakpointToggle."""
        try:
            app = self._get_app()
            if app:
                app.breakpoint_toggle()
        except Exception:
            self.logger.exception('GdbBreakpointToggle Exception')

    @pynvim.function('GdbBreakpointClearAll', sync=True)
    def gdb_breakpoint_clear_all(self, _):
        """Handle command GdbBreakpointClearAll."""
        try:
            app = self._get_app()
            if app:
                app.breakpoint_clear_all()
        except Exception:
            self.logger.exception('GdbBreakpointClearAll Exception')

    @pynvim.function('GdbCallAsync')
    def gdb_call_async(self, args):
        """Handle command GdbCallAsync."""
        try:
            obj = self._get_app()
            if obj:
                for name in args[0].split('.'):
                    obj = getattr(obj, name)
                obj(*args[1:])
        except Exception:
            self.logger.exception('GdbCallAsync Exception')

    @pynvim.function('GdbCall', sync=True)
    def gdb_call(self, args):
        """Make a custom call to the App.

        Reads a period separated list of words and invokes the corresponding
        method on the `App` class.
            e.g.
                self.gdb_call(['custom_command'] + args)
                  maps to
                self.app.custom_command(args)
        """
        try:
            obj = self._get_app()
            if obj:
                for name in args[0].split('.'):
                    obj = getattr(obj, name)
                if callable(obj):
                    return obj(*args[1:])
                return obj
        except Exception:
            self.logger.exception('GdbCall Exception')
        return None
