'''.'''

from gdb.common import Common
from contextlib import contextmanager


class Win(Common):
    '''Jump window management.'''
    def __init__(self, common, cursor, client, break_point, keymaps):
        super().__init__(common)
        # window number that will be displaying the current file
        self.jump_win = None
        self.cursor = cursor
        self.client = client
        self.breakpoint = break_point
        self.keymaps = keymaps

        # Create the default jump window
        self._ensure_jump_window()

    def is_jump_window_active(self):
        '''Check whether the current buffer is displayed in the jump window.'''
        return self.vim.current.buffer == self.jump_win.buffer

    @contextmanager
    def _saved_win(self):
        self.keymaps.set_dispatch_active(False)
        prev_win = self.vim.current.window
        yield
        self.vim.current.window = prev_win
        self.keymaps.set_dispatch_active(True)

    @contextmanager
    def _saved_mode(self):
        mode = self.vim.api.get_mode()
        yield
        if mode['mode'] in "ti":
            self.vim.command("startinsert")

    def _ensure_jump_window(self):
        '''Check that the jump window is available.
           Create a new one otherwise.'''
        wins = self.vim.current.tabpage.windows
        if self.jump_win not in wins:
            # The jump window needs to be created first
            with self._saved_win():
                self.vim.command(self.config.get("codewin_command"))
                self.jump_win = self.vim.current.window

    def jump(self, file, line):
        '''Show the file and the current line in the jump window.'''
        self.log(f"jump({file}:{line})")
        # Check whether the file is already loaded or load it
        target_buf = self.vim.call("bufnr", file, 1)

        # Ensure the jump window is available
        with self._saved_mode():
            self._ensure_jump_window()

        # The terminal buffer may contain the name of the source file
        # (in pdb, for instance).
        if target_buf == self.client.get_buf().handle:
            window = self.vim.current.window
            if self.jump_win != window:
                # We're going to jump to another window and return.
                # There is no need to change keymaps forth and back.
                self.keymaps.set_dispatch_active(False)
                self.vim.command(f"{self.jump_win.number}wincmd w")
            self.vim.command("noswapfile view " + file)
            target_buf = self.vim.call("bufnr", file)
            if self.jump_win != window:
                self.vim.command(f"{window.number}wincmd w")
                self.keymaps.set_dispatch_active(True)

        if self.jump_win.buffer.handle != target_buf:
            with self._saved_mode(), self._saved_win():
                if self.jump_win != self.vim.current.window:
                    self.vim.current.window = self.jump_win
                self.vim.command("noswap e %s" % file)
                self.query_breakpoints()

        # Goto the proper line and set the cursor on it
        self.jump_win.cursor = (line, 0)
        self.cursor.set(target_buf, line)
        self.cursor.show()
        self.vim.command("redraw")

    def query_breakpoints(self):
        '''Show actual breakpoints in the current window.'''
        # Get the source code buffer number
        buf_num = self.jump_win.buffer.handle

        # Get the source code file name
        fname = self.vim.call("expand", f'#{buf_num}:p')

        # If no file name or a weird name with spaces, ignore it (to avoid
        # misinterpretation)
        if fname and fname.find(' ') == -1:
            # Query the breakpoints for the shown file
            self.breakpoint.query(buf_num, fname)
            self.vim.command("redraw")
