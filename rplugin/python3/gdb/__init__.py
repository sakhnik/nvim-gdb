import pynvim
from gdb.app import App

class TStorage:
    def __init__(self, vim):
        self.vim = vim
        self.data = {}

    # Create a tabpage-specific table
    def init(self, tab, val):
        self.data[tab] = val

    # Access the table for the current page
    def get(self):
        return self.data[self.vim.current.tabpage]

    # Access the table for given page
    def getTab(self, tab):
        return self.data[tab]

    # Delete the tabpage-specific table
    def clear(self, tab):
        del(self.data[tab])


@pynvim.plugin
class Gdb(object):
    def __init__(self, vim):
        self.vim = vim
        self.tstorage = TStorage(vim)
        self.calls = 0

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

    @pynvim.function('GdbPy')
    def gdb_py(self, args):
        tab = args[0]
        if args[1] == 'init':
            self.tstorage.init(tab, App(self.vim, *args[2:]))
        elif args[1] == 'cleanup':
            self.tstorage.clear(tab)
        elif args[1] == 'dispatch':
            app = self.tstorage.getTab(tab)
            app.dispatch(args[2:])

    @pynvim.function('GdbPyCall', sync=True)
    def gdb_py_call(self, args):
        tab = args[0]
        if args[1] == 'getCommand':
            app = self.tstorage.getTab(tab)
            return app.getCommand(args[2])
