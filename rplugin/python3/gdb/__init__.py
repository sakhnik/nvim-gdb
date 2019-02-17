import pynvim
from gdb.app import App


@pynvim.plugin
class Gdb(object):
    def __init__(self, vim):
        self.vim = vim
        self.apps = {}

    #@pynvim.command('Cmd', range='', nargs='*', sync=True)
    #def command_handler(self, args, range):
    #    self._increment_calls()
    #    self.vim.current.line = (
    #        'Command: Called %d times, args: %s, range: %s' % (self.calls,
    #                                                           args,
    #                                                           range))

    #@pynvim.autocmd('BufEnter', pattern='*.py', eval='expand("<afile>")',
    #                sync=True)
    #def autocmd_handler(self, filename):
    #    self._increment_calls()
    #    self.vim.current.line = (
    #        'Autocmd: Called %s times, file: %s' % (self.calls, filename))

    def _get_app(self):
        return self.apps[self.vim.current.tabpage.handle]

    @pynvim.function('GdbInit', sync=True)
    def gdb_init(self, args):
        app = App(self.vim, *args)
        self.apps[self.vim.current.tabpage.handle] = app
        app.start()

    @pynvim.function('GdbCleanup', sync=True)
    def gdb_cleanup(self, args):
        tab = self.vim.current.tabpage.handle
        try:
            app = self.apps[tab]
            app.cleanup()
        finally:
            del(self.apps[tab])

    @pynvim.function('GdbCheckTab', sync=True)
    def gdb_check_tab(self, args):
        return self.vim.current.tabpage.handle in self.apps

    @pynvim.function('GdbHandleEvent', sync=True)
    def gdb_handle_event(self, args):
        try:
            app = self._get_app()
            handler = getattr(app, args[0])
            handler()
        except:
            pass

    @pynvim.function('GdbSend', sync=True)
    def gdb_send(self, args):
        try:
            app = self._get_app()
            app.send(*args)
        except:
            pass

    @pynvim.function('GdbBreakpointToggle', sync=True)
    def gdb_breakpoint_toggle(self, args):
        try:
            app = self._get_app()
            app.breakpointToggle()
        except:
            pass

    @pynvim.function('GdbBreakpointClearAll', sync=True)
    def gdb_breakpoint_clear_all(self, args):
        try:
            app = self._get_app()
            app.breakpointClearAll()
        except:
            pass

    @pynvim.function('GdbScmFeed')
    def gdb_scm_feed(self, args):
        try:
            tab = args[0]
            app = self.apps[tab]
            app.scm.feed(args[1])
        except:
            pass

    @pynvim.function('GdbCallAsync')
    def gdb_call_async(self, args):
        try:
            obj = self._get_app()
            for a in args[0].split('.'):
                obj = getattr(obj, a)
            obj(*args[1:])
        except:
            pass

    @pynvim.function('GdbCall', sync=True)
    def gdb_call(self, args):
        try:
            obj = self._get_app()
            for a in args[0].split('.'):
                obj = getattr(obj, a)
            if callable(obj):
                return obj(*args[1:])
            else:
                return obj
        except:
            pass
        return None

    @pynvim.function('GdbCustomCommand', sync=True)
    def gdb_custom_command(self, args):
        return self.gdb_call(["customCommand"] + args)

    @pynvim.function('GdbTestPeek', sync=True)
    def gdb_test_peek(self, args):
        try:
            obj = self._get_app()
            for i in range(len(args)):
                obj = getattr(obj, args[i])
                if callable(obj):
                    return obj(*args[i+1:])
            return obj
        except:
            return None

    @pynvim.function('GdbTestPeekConfig', sync=True)
    def gdb_test_peek_config(self, args):
        try:
            app = self._get_app()
            config = {k:v for k,v in app.config.items()}
            for k, v in config.items():
                if callable(v):
                    config[k] = str(v)
            return config
        except:
            return None
