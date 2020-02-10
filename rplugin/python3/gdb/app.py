'''.'''

from gdb.common import Common
from gdb.cursor import Cursor
from gdb.client import Client
from gdb.win import Win
from gdb.keymaps import Keymaps
from gdb.proxy import Proxy
from gdb.breakpoint import Breakpoint

from gdb.backend.gdb import GdbParser
from gdb.backend.pdb import PdbParser
from gdb.backend.lldb import LldbParser
from gdb.backend.bashdb import BashDBParser


class App(Common):
    '''Main application class.'''

    def __init__(self, common, backendStr, proxyCmd, clientCmd):
        super().__init__(common)
        self._last_command = None

        # Create new tab for the debugging view and split horizontally
        self.vim.command('tabnew'
                         ' | setlocal nowinfixwidth'
                         ' | setlocal nowinfixheight'
                         ' | silent wincmd o')
        self.vim.command(self.config.get("split_command"))
        if len(self.vim.current.tabpage.windows) != 2:
            raise Exception("The split_command should result in exactly two"
                            " windows")

        # Enumerate the available windows
        wins = self.vim.current.tabpage.windows
        wcli, wjump = wins[1], wins[0]

        # Initialize current line tracking
        self.cursor = Cursor(common)

        # Go to the other window and spawn gdb client
        self.client = Client(common, wcli, proxyCmd, clientCmd)

        # Initialize connection to the side channel
        self.proxy = Proxy(common, self.client)

        # Initialize breakpoint tracking
        self.breakpoint = Breakpoint(common, self.proxy)

        # Initialize the keymaps subsystem
        self.keymaps = Keymaps(common)

        # Initialize the windowing subsystem
        self.win = Win(common, wjump, self.cursor, self.client,
                       self.breakpoint, self.keymaps)

        # Get the selected backend module
        backend_maps = {
            "gdb": GdbParser,
            "bashdb": BashDBParser,
            "lldb": LldbParser,
            "pdb": PdbParser
        }
        backend_class = backend_maps[backendStr]

        # Initialize the parser
        self.parser = backend_class(common, self.cursor, self.win)

        # Set initial keymaps in the terminal window.
        self.keymaps.dispatch_set_t()
        self.keymaps.dispatch_set()

        # Start insert mode in the GDB window
        self.vim.feedkeys("i")

    def start(self):
        '''The parser should be ready by now, spawn the debugger!'''
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

        # Cleanup the autocommands associated with this tabpage
        self.vim.command(f"augroup {self._get_autocmd_group_name()}")
        self.vim.command("autocmd!")
        self.vim.command("augroup END")

        # Close the windows and the tab
        tab_count = len(self.vim.tabpages)
        self.client.del_buffer()
        if tab_count == len(self.vim.tabpages):
            self.vim.command("tabclose")

        self.client.cleanup()

    def _get_command(self, cmd):
        return self.parser.command_map.get(cmd, cmd)

    def send(self, *args):
        '''Send a command to the debugger.'''
        if args:
            command = self._get_command(args[0]).format(*args[1:])
            self.client.send_line(command)
            self._last_command = command  # Remember the command for testing
        else:
            self.client.interrupt()

    def custom_command(self, cmd):
        '''Execute a custom debugger command and return its output.'''
        return self.proxy.query("handle-command " + cmd)

    def _get_autocmd_group_name(self):
        '''Create a unique autocmd group name for this tab.'''
        return f"NvimGdbTab{self.vim.current.tabpage.number}";

    def create_watch(self, cmd):
        '''Create a window to watch for a debugger expression.
           The output of the expression or command will be displayed
           in that window.
        '''
        self.vim.command("vnew | set readonly buftype=nowrite")
        buf = self.vim.current.buffer
        buf.name = cmd
        self.vim.command(f"augroup {self._get_autocmd_group_name()}")
        self.vim.command("autocmd User NvimGdbQuery"
                f" call nvim_buf_set_lines({buf.number}, 0, -1, 0,"
                f" split(GdbCustomCommand('{cmd}'), '\\n'))")
        self.vim.command("augroup END")

    def breakpoint_toggle(self):
        '''Toggle breakpoint in the cursor line.'''
        if self.parser.is_running():
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
        if self.parser.is_running():
            # pause first
            self.client.interrupt()
        # The breakpoint signs will be requeried later automatically
        self.send('delete_breakpoints')

    def on_tab_enter(self):
        '''Actions to execute when a tabpage is entered.'''
        # Restore the signs as they may have been spoiled
        if self.parser.is_paused():
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

            scroll_off = self.config.get_or('set_scroll_off', None)
            if scroll_off is not None:
                self.vim.command("if !&scrolloff"
                                 f" | setlocal scrolloff={str(scroll_off)}"
                                 " | endif")
            self.keymaps.dispatch_set()
            # Ensure breakpoints are shown if are queried dynamically
            self.win.query_breakpoints()

    def on_buf_leave(self):
        '''Actions to execute when a buffer is left.'''
        if self.vim.current.buffer.options['buftype'] != 'terminal':
            self.keymaps.dispatch_unset()
        else:
            self.vim.command("normal G")
