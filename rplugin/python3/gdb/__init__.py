'''Plugin entry point.'''

# pylint: disable=broad-except
import re
import pynvim   # type: ignore
from gdb.common import BaseCommon, Common
from gdb.app import App
from gdb.config import Config
from gdb.logger import LOGGING_CONFIG
from contextlib import contextmanager
import logging
import logging.config


@pynvim.plugin
class Gdb(Common):
    '''Plugin implementation.'''
    def __init__(self, vim):
        logging.config.dictConfig(LOGGING_CONFIG)
        common = BaseCommon(vim, None)
        super().__init__(common)
        self.apps = {}
        self.ansi_escaper = re.compile(r'\x1B[@-_][0-?]*[ -/]*[@-~]')

    def _get_app(self):
        return self.apps.get(self.vim.current.tabpage.handle, None)

    @pynvim.function('GdbInit', sync=True)
    def gdb_init(self, args):
        '''Command GdbInit.'''
        # Prepare configuration: keymaps, hooks, parameters etc.
        common = BaseCommon(self.vim, Config(self))
        app = App(common, *args)
        self.apps[self.vim.current.tabpage.handle] = app
        app.start()
        if len(self.apps) == 1:
            # Initialize the UI commands, autocommands etc
            self.vim.call("nvimgdb#GlobalInit")

    @contextmanager
    def _saved_hidden(self):
        # Prevent "ghost" [noname] buffers when leaving debug when 'hidden' is on
        hidden = self.vim.eval("&hidden")
        if hidden:
            self.vim.command("set nohidden")
        yield
        # sets hidden back to user default
        if hidden:
            self.vim.command("set hidden")

    @pynvim.function('GdbCleanup', sync=True)
    def gdb_cleanup(self, args):
        '''Command GdbCleanup.'''
        tab = int(args[0])
        self.logger.info(f"Cleanup tab={tab}")
        try:
            app = self.apps.pop(tab, None)
            if app:
                with self._saved_hidden():
                    if len(self.apps) == 0:
                        # Cleanup commands, autocommands etc
                        self.vim.call("nvimgdb#GlobalCleanup")
                    app.cleanup(tab)
                # TabEnter isn't fired automatically when a tab is closed
                self.gdb_handle_event(["on_tab_enter"])
        except Exception:
            self.logger.exception("FIXME GdbCleanup Exception")

    @pynvim.function('GdbHandleEvent', sync=True)
    def gdb_handle_event(self, args):
        '''Command GdbHandleEvent.'''
        self.logger.info(f"GdbHandleEvent {' '.join(args)}")
        try:
            app = self._get_app()
            if app:
                handler = getattr(app, args[0])
                handler()
        except Exception:
            self.logger.exception("GdbHandleEvent Exception")

    @pynvim.function('GdbHandleTabClosed', sync=True)
    def gdb_handle_tab_closed(self, args):
        '''Function GdbHandleTabClosed.'''
        self.logger.info("GdbHandleTabClosed")
        active_tabs = {t.handle for t in self.vim.tabpages}
        managed_tabs = {t for t in self.apps.keys()}
        closed_tabs = managed_tabs.difference(active_tabs)
        for t in closed_tabs:
            self.gdb_cleanup([t])

    @pynvim.function('GdbHandleVimLeavePre', sync=True)
    def gdb_handle_vim_leave_pre(self, args):
        '''Function GdbHandleVimLeavePre.'''
        self.logger.info("GdbHandleVimLeavePre")
        # Make sure a copy of the list is made.
        for t in [t for t in self.apps.keys()]:
            self.gdb_cleanup([t])

    @pynvim.function('GdbSend', sync=True)
    def gdb_send(self, args):
        '''Command GdbSend.'''
        try:
            app = self._get_app()
            if app:
                app.send(*args)
        except Exception:
            self.logger.exception("GdbSend Exception")

    @pynvim.function('GdbBreakpointToggle', sync=True)
    def gdb_breakpoint_toggle(self, _):
        '''Command GdbBreakpointToggle.'''
        try:
            app = self._get_app()
            if app:
                app.breakpoint_toggle()
        except Exception:
            self.logger.exception('GdbBreakpointToggle Exception')

    @pynvim.function('GdbBreakpointClearAll', sync=True)
    def gdb_breakpoint_clear_all(self, _):
        '''Command GdbBreakpointClearAll.'''
        try:
            app = self._get_app()
            if app:
                app.breakpoint_clear_all()
        except Exception:
            self.logger.exception('GdbBreakpointClearAll Exception')

    @pynvim.function('GdbParserFeed')
    def gdb_parser_feed(self, args):
        '''Command GdbParserFeed.'''

        try:
            tab = args[0]
            app = self.apps.get(tab, None)
            if app:
                content = args[1]
                for i, ele in enumerate(content):
                    content[i] = self.ansi_escaper.sub('', ele)
                app.parser.feed(content)
        except Exception:
            self.logger.exception('GdbParserFeed Exception')

    @pynvim.function('GdbCallAsync')
    def gdb_call_async(self, args):
        '''Command GdbCallAsync.'''
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
        '''
        Reads a period separated list of words and invokes the corresponding
        method on the `App` class.
            e.g.
                self.gdb_call(['custom_command'] + args)
                  maps to
                self.app.custom_command(args)
        '''
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

    @pynvim.function('GdbCustomCommand', sync=True)
    def gdb_custom_command(self, args):
        '''Command GdbCustomCommand.'''
        return self.gdb_call(["custom_command"] + args)

    @pynvim.function('GdbCreateWatch', sync=True)
    def gdb_create_watch(self, args):
        '''Command GdbCreateWatch.'''
        return self.gdb_call(["create_watch"] + args)

    @pynvim.function('GdbTestPeek', sync=True)
    def gdb_test_peek(self, args):
        '''Command GdbTestPeek.'''
        try:
            obj = self._get_app()
            if obj:
                for i, arg in enumerate(args):
                    obj = getattr(obj, arg)
                    if callable(obj):
                        return obj(*args[i+1:])
                return obj
        except Exception:
            self.logger.exception('GdbTestPeek Exception')
            return None

    @pynvim.function('GdbTestPeekConfig', sync=True)
    def gdb_test_peek_config(self, _):
        '''Command GdbTestPeekConfig.'''
        try:
            app = self._get_app()
            if app:
                config = {k: v for k, v in app.config.config.items()}
                for key, val in config.items():
                    if callable(val):
                        config[key] = str(val)
                return config
        except Exception:
            self.logger.exception('GdbTestPeekConfig Exception')
            return None
