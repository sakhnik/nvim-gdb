'''Plugin entry point.'''

# pylint: disable=broad-except
import re
from typing import Dict, List, Union

import pynvim  # type: ignore

from gdb.app import App
from gdb.common import BaseCommon, Common
from gdb.config import Config
from gdb.logger import Logger


@pynvim.plugin
class Gdb(Common):
    '''Plugin implementation.'''

    def __init__(self, vim: pynvim.api.nvim.Nvim):
        common = BaseCommon(vim, Logger(), None)
        super().__init__(common)
        self.apps: Dict[int, App] = {}
        self.ansi_escaper = re.compile(r'\x1B[@-_][0-?]*[ -/]*[@-~]')

    def _get_app(self):
        return self.apps[self.vim.current.tabpage.handle]

    @pynvim.function('GdbInit', sync=True)
    def gdb_init(self, args: List[str]):
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

    @pynvim.function('GdbParserFeed')
    def gdb_parser_feed(self, args: List[Union[List[str], int]]):
        '''Command GdbParserFeed.'''
        try:
            tab = args[0]
            if isinstance(tab, int):
                app = self.apps[tab]
            else:
                raise Exception("App index wasn't an int.")
            content = args[1]
            if isinstance(content, list):
                for i, ele in enumerate(content):
                    content[i] = self.ansi_escaper.sub('', ele)
                app.parser.feed(content)
            else:
                raise Exception("Expected a list of strings from debugger.")
        except Exception as ex:
            self.log('GdbParserFeed: ' + str(ex))

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
        val = self.gdb_call(["custom_command"] + args)
        return val

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
