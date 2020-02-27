'''Plugin entry point.'''

# pylint: disable=broad-except
import re
import pynvim   # type: ignore
from gdb.common import BaseCommon, Common
from gdb.app import App
from gdb.config import Config
from gdb.logger import Logger
from contextlib import contextmanager


@pynvim.plugin
class Gdb(Common):
    '''Plugin implementation.'''
    def __init__(self, vim):
        common = BaseCommon(vim, Logger(), None)
        super().__init__(common)
        self.apps = {}
        self.ansi_escaper = re.compile(r'\x1B[@-_][0-?]*[ -/]*[@-~]')

    def _get_app(self):
        return self.apps.get(self.vim.current.tabpage.handle, None)

    @pynvim.function('GdbInit', sync=True)
    def gdb_init(self, args):
        '''Command GdbInit.'''
        # Prepare configuration: keymaps, hooks, parameters etc.
        common = BaseCommon(self.vim, self.logger, Config(self))
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
        self.log(f"Cleanup tab={tab}")
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
        except Exception as ex:
            self.log("FIXME GdbCleanup Exception: " + str(ex))

    @pynvim.function('GdbHandleEvent', sync=True)
    def gdb_handle_event(self, args):
        '''Command GdbHandleEvent.'''
        self.log(f"GdbHandleEvent {' '.join(args)}")
        try:
            app = self._get_app()
            if app:
                handler = getattr(app, args[0])
                handler()
        except Exception as ex:
            self.log("GdbHandleEvent Exception: " + str(ex))

    @pynvim.function('GdbHandleTabClosed', sync=True)
    def gdb_handle_tab_closed(self, args):
        '''Command GdbHandleTabClosed.'''
        self.log("GdbHandleTabClosed")
        active_tabs = {t.handle for t in self.vim.tabpages}
        managed_tabs = {t for t in self.apps.keys()}
        closed_tabs = managed_tabs.difference(active_tabs)
        for t in closed_tabs:
            self.gdb_cleanup([t])

    @pynvim.function('GdbSend', sync=True)
    def gdb_send(self, args):
        '''Command GdbSend.'''
        try:
            app = self._get_app()
            if app:
                app.send(*args)
        except Exception as ex:
            self.log("GdbSend Exception: " + str(ex))

    @pynvim.function('GdbBreakpointToggle', sync=True)
    def gdb_breakpoint_toggle(self, _):
        '''Command GdbBreakpointToggle.'''
        try:
            app = self._get_app()
            if app:
                app.breakpoint_toggle()
        except Exception as ex:
            self.log('GdbBreakpointToggle Exception: ' + str(ex))

    @pynvim.function('GdbBreakpointClearAll', sync=True)
    def gdb_breakpoint_clear_all(self, _):
        '''Command GdbBreakpointClearAll.'''
        try:
            app = self._get_app()
            if app:
                app.breakpoint_clear_all()
        except Exception as ex:
            self.log('GdbBreakpointClearAll Exception: ' + str(ex))

    @pynvim.function('GdbParserFeed')
    def gdb_parser_feed(self, args):
        '''Command GdbParserFeed.'''

        try:
            tab = args[0]
            app = self.apps[tab]
            content = args[1]
            for i, ele in enumerate(content):
                content[i] = self.ansi_escaper.sub('', ele)
            app.parser.feed(content)
        except Exception as ex:
            self.log('GdbParserFeed Exception: ' + str(ex))

    @pynvim.function('GdbCallAsync')
    def gdb_call_async(self, args):
        '''Command GdbCallAsync.'''
        try:
            obj = self._get_app()
            if obj:
                for name in args[0].split('.'):
                    obj = getattr(obj, name)
                obj(*args[1:])
        except Exception as ex:
            self.log('GdbCallAsync Exception: ' + str(ex))

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
        except Exception as ex:
            self.log('GdbCall Exception: ' + str(ex))
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
        except Exception as ex:
            self.log('GdbTestPeek Exception: ' + str(ex))
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
        except Exception as ex:
            self.log('GdbTestPeekConfig Exception: ' + str(ex))
            return None
