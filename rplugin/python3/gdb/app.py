'''.'''

import importlib
from gdb.config import get_config
from gdb.common import Common
from gdb.cursor import Cursor
from gdb.client import Client
from gdb.win import Win
from gdb.keymaps import Keymaps
from gdb.proxy import Proxy
from gdb.breakpoint import Breakpoint


class App(Common):
    '''Main application class.'''
    def __init__(self, common, backendStr, proxyCmd, clientCmd):
        super().__init__(common)
        self._last_command = None

        # Prepare configuration: keymaps, hooks, parameters etc.
        self.config = get_config(self.vim, self.logger)
        self._define_signs(self.config)

        # Create new tab for the debugging view and split horizontally
        self.vim.command('tabnew'
                         ' | setlocal nowinfixwidth'
                         ' | setlocal nowinfixheight'
                         ' | silent wincmd o')
        self.vim.command(self.config["split_command"])
        if len(self.vim.current.tabpage.windows) != 2:
            raise Exception("The split_command should result in exactly two"
                            " windows")

        # Enumerate the available windows
        wins = self.vim.current.tabpage.windows
        wcli, wjump = wins[1], wins[0]

        # Import the desired backend module
        self.backend = importlib \
            .import_module("gdb.backend." + backendStr) \
            .init()

        # Initialize current line tracking
        self.cursor = Cursor(common)

        # Go to the other window and spawn gdb client
        self.client = Client(common, wcli, proxyCmd, clientCmd)

        # Initialize connection to the side channel
        self.proxy = Proxy(common, self.client)

        # Initialize breakpoint tracking
        self.breakpoint = Breakpoint(common, self.config, self.proxy)

        # Initialize the keymaps subsystem
        self.keymaps = Keymaps(common, self.config)

        # Initialize the windowing subsystem
        self.win = Win(common, wjump, self.cursor, self.client,
                       self.breakpoint, self.keymaps)

        # Initialize the SCM
        self.scm = self.backend["initScm"](common, self.cursor, self.win)

        # Set initial keymaps in the terminal window.
        self.keymaps.dispatch_set_t()
        self.keymaps.dispatch_set()

        # Start insert mode in the GDB window
        self.vim.feedkeys("i")

    def start(self):
        '''The SCM should be ready by now, spawn the debugger!'''
        self.client.start()
        self.vim.command("doautocmd User NvimGdbStart")

    def cleanup(self):
        '''Finish up the debugging session.'''
        self.vim.command("doautocmd User NvimGdbCleanup")

        # Clean up the breakpoint signs
        self.breakpoint.reset_signs()

        # Clean up the current line sign
        self.cursor.hide()

        # Close connection to the side channel
        self.proxy.cleanup()

        # Close the windows and the tab
        tab_count = len(self.vim.tabpages)
        self.client.del_buffer()
        if tab_count == len(self.vim.tabpages):
            self.vim.command("tabclose")

        self.client.cleanup()

    def _define_signs(self, config):
        # Define the sign for current line the debugged program is executing.
        self.vim.command("sign define GdbCurrentLine text="
                         + config["sign_current_line"])
        # Define signs for the breakpoints.
        breaks = config["sign_breakpoint"]
        for i, brk in enumerate(breaks):
            self.vim.command('sign define GdbBreakpoint{} text={}'
                             .format((i+1), brk))

    def _get_command(self, cmd):
        return self.backend.get(cmd, cmd)

    def send(self, *args):
        '''Send a command to the debugger.'''
        if args:
            command = self.backend.get(args[0], args[0]).format(*args[1:])
            self.client.send_line(command)
            self._last_command = command  # Remember the command for testing
        else:
            self.client.interrupt()

    def custom_command(self, cmd):
        '''Execute a custom debugger command and return its output.'''
        return self.proxy.query("handle-command " + cmd)

    def breakpoint_toggle(self):
        '''Toggle breakpoint in the cursor line.'''
        if self.scm.is_running():
            # pause first
            self.client.interrupt()
        buf = self.vim.current.buffer
        file_name = self.vim.call("expand", '#%d:p' % buf.handle)
        line_nr = self.vim.call("line", ".")
        breaks = self.breakpoint.get_for_file(file_name, line_nr)

        if breaks:
            # There already is a breakpoint on this line: remove
            del_br = self._get_command('delete_breakpoints')
            self.client.send_line(f"{del_br} {breaks[-1]}")
        else:
            set_br = self._get_command('breakpoint')
            self.client.send_line(f"{set_br} {file_name}:{line_nr}")

    def breakpoint_clear_all(self):
        '''Clear all breakpoints.'''
        if self.scm.is_running():
            # pause first
            self.client.interrupt()
        # The breakpoint signs will be requeried later automatically
        self.send('delete_breakpoints')

    def on_tab_enter(self):
        '''Actions to execute when a tabpage is entered.'''
        # Restore the signs as they may have been spoiled
        if self.scm.is_paused():
            self.cursor.show()
        # Ensure breakpoints are shown if are queried dynamically
        self.win.query_breakpoints()

    def on_tab_leave(self):
        '''Actions to execute when a tabpage is left.'''
        # Hide the signs
        self.cursor.hide()
        self.breakpoint.clear_signs()

    def on_buf_enter(self):
        '''Actions to execute when a buffer is entered.'''
        # Apply keymaps to the jump window only.
        if self.vim.current.buffer.options['buftype'] != 'terminal' \
                and self.win.is_jump_window_active():
            # Make sure the cursor stay visible at all times

            if "set_scroll_off" in self.config:
                soff_val = str(self.config['set_scroll_off'])
                self.vim.command("if !&scrolloff | setlocal scrolloff={}"
                                 " | endif".format(soff_val))
            self.keymaps.dispatch_set()
            # Ensure breakpoints are shown if are queried dynamically
            self.win.query_breakpoints()

    def on_buf_leave(self):
        '''Actions to execute when a buffer is left.'''
        if self.vim.current.buffer.options['buftype'] != 'terminal':
            self.keymaps.dispatch_unset()
