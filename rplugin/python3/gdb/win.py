'''.'''

from pynvim import NvimError  # type: ignore
from gdb.common import Common


class Win(Common):
    '''Jump window management.'''
    def __init__(self, common, win, cursor, client, break_point):
        super().__init__(common)
        # window number that will be displaying the current file
        self.jump_win = win
        self.cursor = cursor
        self.client = client
        self.breakpoint = break_point

    def is_jump_window_active(self):
        '''Check whether the current buffer is displayed in the jump window.'''
        return self.vim.current.buffer == self.jump_win.buffer

    def jump(self, file, line):
        '''Show the file and the current line in the jump window.'''
        # Check whether the file is already loaded or load it
        target_buf = self.vim.call("bufnr", file, 1)
        # The terminal buffer may contain the name of the source file
        # (in pdb, for instance).
        if target_buf == self.client.get_buf().handle:
            self.vim.command("noswapfile view " + file)
            target_buf = self.vim.call("bufnr", file)
        if self.jump_win.buffer.handle != target_buf:
            try:
                # This file being opened having a .swp file causes this
                # function to throw
                self.vim.call("nvim_win_set_buf", self.jump_win.handle,
                              target_buf)
            except NvimError as ex:
                self.log(f'Exception: {str(ex)}')
            # TODO: figure out if other autocommands need ran here.
            # e.g. BufReadPost is required for syntax highlighting
            self.vim.command("doautoa BufReadPost")
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
