"""."""

from contextlib import contextmanager
from gdb.common import Common
from gdb.cursor import Cursor
from gdb.client import Client
from gdb.breakpoint import Breakpoint
from gdb.keymaps import Keymaps


class Win(Common):
    """Jump window management."""

    def __init__(self, common: Common, cursor: Cursor, client: Client,
                 break_point: Breakpoint, keymaps: Keymaps):
        """ctor."""
        super().__init__(common)
        # window number that will be displaying the current file
        self.jump_win = None
        self.cursor = cursor
        self.client = client
        self.breakpoint = break_point
        self.keymaps = keymaps

        # Create the default jump window
        self._ensure_jump_window()

    def _has_jump_win(self):
        """Check whether the jump window is displayed."""
        return self.jump_win in self.vim.current.tabpage.windows

    def is_jump_window_active(self):
        """Check whether the current buffer is displayed in the jump window."""
        if not self._has_jump_win():
            return False
        return self.vim.current.buffer == self.jump_win.buffer

    @contextmanager
    def _saved_win(self):
        # We're going to jump to another window and return.
        # There is no need to change keymaps forth and back.
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
        """Ensure that the jump window is available."""
        if not self._has_jump_win():
            # The jump window needs to be created first
            with self._saved_win():
                self.vim.command(self.config.get("codewin_command"))
                self.jump_win = self.vim.current.window

    def jump(self, file: str, line: int):
        """Show the file and the current line in the jump window."""
        self.logger.info("jump(%s:%d)", file, line)
        # Check whether the file is already loaded or load it
        target_buf = self.vim.call("bufnr", file, 1)

        # Ensure the jump window is available
        with self._saved_mode():
            self._ensure_jump_window()
        if not self.jump_win:
            raise AssertionError("No jump window")

        # The terminal buffer may contain the name of the source file
        # (in pdb, for instance).
        if target_buf == self.client.get_buf().handle:
            with self._saved_win():
                self.vim.current.window = self.jump_win
                self.vim.command("noswapfile view " + file)
                target_buf = self.vim.call("bufnr", file)

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
        """Show actual breakpoints in the current window."""
        if not self._has_jump_win():
            return

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
