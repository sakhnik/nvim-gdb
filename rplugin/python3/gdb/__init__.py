'''Plugin entry point.'''

# pylint: disable=broad-except

import pynvim
from gdb.common import BaseCommon, Common
from gdb.app import App
from gdb.config import Config
from gdb.logger import Logger


@pynvim.plugin
class Gdb(Common):
    '''Plugin implementation.'''
    def __init__(self, vim):
        common = BaseCommon(vim, Logger(), None)
        super().__init__(common)
        self.apps = {}

    def _get_app(self):
        return self.apps[self.vim.current.tabpage.handle]

    @pynvim.function('GdbInit', sync=True)
    def gdb_init(self, args):
        '''Command GdbInit.'''
        # Prepare configuration: keymaps, hooks, parameters etc.
        common = BaseCommon(self.vim, self.logger, Config(self))
        app = App(common, *args)
        self.apps[self.vim.current.tabpage.handle] = app
        app.start()

    @pynvim.function('GdbCleanup', sync=True)
    def gdb_cleanup(self, _):
        '''Command GdbCleanup.'''
        tab = self.vim.current.tabpage.handle
        try:
            app = self.apps[tab]
            app.cleanup()
        finally:
            del self.apps[tab]

    @pynvim.function('GdbCheckTab', sync=True)
    def gdb_check_tab(self, _):
        '''Command GdbCheckTab.'''
        try:
            return self.vim.current.tabpage.handle in self.apps
        except Exception as ex:
            self.log("GdbCheckTab: " + str(ex))

    @pynvim.function('GdbHandleEvent', sync=True)
    def gdb_handle_event(self, args):
        '''Command GdbHandleEvent.'''
        try:
            app = self._get_app()
            handler = getattr(app, args[0])
            handler()
        except Exception as ex:
            self.log("GdbHandleEvent: " + str(ex))

    @pynvim.function('GdbSend', sync=True)
    def gdb_send(self, args):
        '''Command GdbSend.'''
        try:
            app = self._get_app()
            app.send(*args)
        except Exception as ex:
            self.log("GdbSend: " + str(ex))

    @pynvim.function('GdbBreakpointToggle', sync=True)
    def gdb_breakpoint_toggle(self, _):
        '''Command GdbBreakpointToggle.'''
        try:
            app = self._get_app()
            app.breakpoint_toggle()
        except Exception as ex:
            self.log('GdbBreakpointToggle: ' + str(ex))

    @pynvim.function('GdbBreakpointClearAll', sync=True)
    def gdb_breakpoint_clear_all(self, _):
        '''Command GdbBreakpointClearAll.'''
        try:
            app = self._get_app()
            app.breakpoint_clear_all()
        except Exception as ex:
            self.log('GdbBreakpointClearAll: ' + str(ex))

    @pynvim.function('GdbScmFeed')
    def gdb_scm_feed(self, args):
        '''Command GdbScmFeed.'''
        try:
            tab = args[0]
            app = self.apps[tab]
            app.scm.feed(args[1])
        except Exception as ex:
            self.log('GdbScmFeed: ' + str(ex))

    @pynvim.function('GdbCallAsync')
    def gdb_call_async(self, args):
        '''Command GdbCallAsync.'''
        try:
            obj = self._get_app()
            for name in args[0].split('.'):
                obj = getattr(obj, name)
            obj(*args[1:])
        except Exception as ex:
            self.log('GdbCallAsync: ' + str(ex))

    @pynvim.function('GdbCall', sync=True)
    def gdb_call(self, args):
        '''Command GdbCall.'''
        try:
            obj = self._get_app()
            for name in args[0].split('.'):
                obj = getattr(obj, name)
            if callable(obj):
                return obj(*args[1:])
            return obj
        except Exception as ex:
            self.log('GdbCall: ' + str(ex))
        return None

    @pynvim.function('GdbCustomCommand', sync=True)
    def gdb_custom_command(self, args):
        '''Command GdbCustomCommand.'''
        return self.gdb_call(["custom_command"] + args)

    @pynvim.function('GdbTestPeek', sync=True)
    def gdb_test_peek(self, args):
        '''Command GdbTestPeek.'''
        try:
            obj = self._get_app()
            for i, arg in enumerate(args):
                obj = getattr(obj, arg)
                if callable(obj):
                    return obj(*args[i+1:])
            return obj
        except Exception as ex:
            self.log('GdbTestPeek: ' + str(ex))
            return None

    @pynvim.function('GdbTestPeekConfig', sync=True)
    def gdb_test_peek_config(self, _):
        '''Command GdbTestPeekConfig.'''
        try:
            app = self._get_app()
            config = {k: v for k, v in app.config.config.items()}
            for key, val in config.items():
                if callable(val):
                    config[key] = str(val)
            return config
        except Exception as ex:
            self.log('GdbTestPeekConfig: ' + str(ex))
            return None
