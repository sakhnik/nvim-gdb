"""."""

import re
from typing import Union, Dict, Type

from gdb.common import Common
from gdb.client import Client
from gdb.win import Win
from gdb.proxy import Proxy
from gdb.breakpoint import Breakpoint
from gdb.parser import ParserAdapter

from gdb.backend import base
from gdb.backend.gdb import Gdb
from gdb.backend.pdb import Pdb
from gdb.backend.lldb import Lldb
from gdb.backend.bashdb import BashDB


class App(Common):
    """Main application class."""

    def __init__(self, common, backendStr: str, proxyCmd: str,
                 clientCmd: str):
        """ctor."""
        super().__init__(common)
        self._last_command: Union[str, None] = None

        # Create new tab for the debugging view and split horizontally
        self.vim.command('tabnew'
                         ' | setlocal nowinfixwidth'
                         ' | setlocal nowinfixheight'
                         ' | silent wincmd o')

        # TODO: read the configuration before creating a new tabpage
        self.vim.exec_lua(f"nvimgdb.new('{backendStr}')")

        # Get the selected backend module
        backend_maps: Dict[str, Type[base.BaseBackend]] = {
            "gdb": Gdb,
            "bashdb": BashDB,
            "lldb": Lldb,
            "pdb": Pdb,
        }
        self.backend = backend_maps[backendStr]()

        # Go to the other window and spawn gdb client
        self.client = Client(common, proxyCmd, clientCmd)

        # Initialize connection to the side channel
        self.proxy = Proxy(common, self.client)

        # Initialize breakpoint tracking
        breakpoint_impl = self.backend.create_breakpoint_impl(self.proxy)
        self.breakpoint = Breakpoint(common, self.proxy, breakpoint_impl)

        # Initialize the windowing subsystem
        self.win = Win(common, self.client, self.breakpoint)

        # Initialize the parser
        parser_adapter = ParserAdapter(common, self.win)
        self.parser = self.backend.create_parser_impl(common, parser_adapter)

        # Set initial keymaps in the terminal window.
        self.vim.exec_lua("nvimgdb.i().keymaps:dispatch_set_t()")
        self.vim.exec_lua("nvimgdb.i().keymaps:dispatch_set()")

        # Start insert mode in the GDB window
        self.vim.feedkeys("i")

    def start(self):
        """Spawn the debugger, the parser should be ready by now."""
        self.client.start()
        self.vim.command("doautocmd User NvimGdbStart")

    def cleanup(self, tab):
        """Finish up the debugging session."""
        self.vim.command("doautocmd User NvimGdbCleanup")

        # Clean up the breakpoint signs
        self.breakpoint.reset_signs()

        # Clean up the windows and buffers
        self.win.cleanup()

        # Close connection to the side channel
        self.proxy.cleanup()

        # Close the debugger backend
        self.client.cleanup()

        self.vim.command(f"lua require('nvimgdb').cleanup({tab})")

        # Close the windows and the tab
        for tabpage in self.vim.tabpages:
            if tabpage.handle == tab:
                self.vim.command(f"tabclose! {tabpage.number}")

    def _get_command(self, cmd):
        return self.backend.translate_command(cmd)

    def send(self, *args):
        """Send a command to the debugger."""
        if args:
            command = self._get_command(args[0]).format(*args[1:])
            self.client.send_line(command)
            self._last_command = command  # Remember the command for testing
        else:
            self.client.interrupt()

    def custom_command(self, cmd):
        """Execute a custom debugger command and return its output."""
        return self.proxy.query("handle-command " + cmd)

    def create_watch(self, cmd):
        """Create a window to watch for a debugger expression.

        The output of the expression or command will be displayed
        in that window.
        """
        self.vim.command("vnew | set readonly buftype=nowrite")
        self.vim.exec_lua("nvimgdb.i().keymaps:dispatch_set()")
        buf = self.vim.current.buffer
        buf.name = cmd

        cur_tabpage = self.vim.current.tabpage.number
        augroup_name = f"NvimGdbTab{cur_tabpage}_{buf.number}"

        self.vim.command(f"augroup {augroup_name}")
        self.vim.command("autocmd!")
        self.vim.command("autocmd User NvimGdbQuery"
                         f" call nvim_buf_set_lines({buf.number}, 0, -1, 0,"
                         f" split(GdbCustomCommand('{cmd}'), '\\n'))")
        self.vim.command("augroup END")

        # Destroy the autowatch automatically when the window is gone.
        self.vim.command("autocmd BufWinLeave <buffer> call"
                         f" nvimgdb#ClearAugroup('{augroup_name}')")
        # Destroy the watch buffer.
        self.vim.command("autocmd BufWinLeave <buffer> call timer_start(100,"
                         f" {{ -> execute('bwipeout! {buf.number}') }})")
        # Return the cursor to the previous window
        self.vim.command("wincmd l")

    def breakpoint_toggle(self):
        """Toggle breakpoint in the cursor line."""
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
        """Clear all breakpoints."""
        if self.parser.is_running():
            # pause first
            self.client.interrupt()
        # The breakpoint signs will be requeried later automatically
        self.send('delete_breakpoints')

    def on_tab_enter(self):
        """Actions to execute when a tabpage is entered."""
        # Restore the signs as they may have been spoiled
        if self.parser.is_paused():
            self.vim.exec_lua("nvimgdb.i().cursor:show()")
        # Ensure breakpoints are shown if are queried dynamically
        self.win.query_breakpoints()

    def on_tab_leave(self):
        """Actions to execute when a tabpage is left."""
        # Hide the signs
        self.vim.exec_lua("nvimgdb.i().cursor:hide()")
        self.breakpoint.clear_signs()

    def on_buf_enter(self):
        """Actions to execute when a buffer is entered."""
        # Apply keymaps to the jump window only.
        if self.vim.current.buffer.options['buftype'] != 'terminal' \
                and self.win.is_jump_window_active():
            # Make sure the cursor stay visible at all times

            scroll_off = self.vim.exec_lua("return nvimgdb.i().config:get('set_scroll_off')")
            if scroll_off is not None:
                self.vim.command("if !&scrolloff"
                                 f" | setlocal scrolloff={str(scroll_off)}"
                                 " | endif")
            self.vim.exec_lua("nvimgdb.i().keymaps:dispatch_set()")
            # Ensure breakpoints are shown if are queried dynamically
            self.win.query_breakpoints()

    def on_buf_leave(self):
        """Actions to execute when a buffer is left."""
        if self.vim.current.buffer.options['buftype'] == 'terminal':
            # Move the cursor to the end of the buffer
            self.vim.command("$")
            return
        if self.win.is_jump_window_active():
            self.vim.exec_lua("nvimgdb.i().keymaps:dispatch_unset()")

    def lopen(self, kind, mods):
        """Load backtrace or breakpoints into the location list."""
        cmd = ''
        if kind == "backtrace":
            cmd = self.backend.translate_command('bt')
        elif kind == "breakpoints":
            cmd = self.backend.translate_command('info breakpoints')
        else:
            self.logger.warning("Unknown lopen kind %s", kind)
            return
        self.win.lopen(cmd, kind, mods)

    def get_for_llist(self, kind, cmd):
        output = self.custom_command(cmd)
        lines = re.split(r'[\r\n]+', output)
        if kind == "backtrace":
            return lines
        elif kind == "breakpoints":
            return self.backend.llist_filter_breakpoints(lines)
        else:
            self.logger.warning("Unknown lopen kind %s", kind)
