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
        return self.apps[self.vim.current.tabpage.number]

    @pynvim.function('GdbInit', sync=True)
    def gdb_init(self, args):
        app = App(self.vim, *args)
        self.apps[self.vim.current.tabpage.number] = app
        app.start()


    @pynvim.function('GdbCleanup', sync=True)
    def gdb_cleanup(self, args):
        tab = self.vim.current.tabpage.number
        app = self.apps[tab]
        app.cleanup()
        del(self.apps[tab])

    # TODO: Decrease usage of this function TOCTOU
    @pynvim.function('GdbCheckTab', sync=True)
    def gdb_check_tab(self, args):
        return self.vim.current.tabpage.number in self.apps

    @pynvim.function('GdbTabEnter')
    def gdb_tab_enter(self, args):
        app = self._get_app()
        app.tabEnter()

    @pynvim.function('GdbPyAsync')
    def gdb_py_async(self, args):
        tab = args[0]
        if args[1] == 'cleanup':
            app = self.apps[tab]
            app.cleanup()
            del(self.apps[tab])
        elif args[1] == 'dispatch':
            app = self.apps[tab]
            app.dispatch(args[2:])

    @pynvim.function('GdbPy', sync=True)
    def gdb_py(self, args):
        tab = args[0]
        if args[1] == 'getCommand':
            app = self.apps[tab]
            return app.getCommand(args[2])
        elif args[1] == 'dispatch':
            app = self.apps[tab]
            return app.dispatch(args[2:])
