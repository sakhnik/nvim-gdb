from pynvim import NvimError
class Win:
    def __init__(self, vim, win, cursor, client, breakpoint, keymaps):
        self.vim = vim
        # window number that will be displaying the current file
        self.jumpWin = win
        self.cursor = cursor
        self.client = client
        self.breakpoint = breakpoint
        self.keymaps = keymaps

    def jump(self, file, line):
        # Check whether the file is already loaded or load it
        targetBuf = self.vim.call("bufnr", file, 1)
        # The terminal buffer may contain the name of the source file (in pdb, for
        # instance)
        if targetBuf == self.client.getBuf().handle:
            self.vim.command("noswapfile view " + file)
            targetBuf = self.vim.call("bufnr", file)
        if self.jumpWin.buffer.handle != targetBuf:
            try:
                # This file being opened having a .swp file causes this function to throw
                self.vim.call("nvim_win_set_buf", self.jumpWin.handle, targetBuf)
            except NvimError as e:
                pass
            # TODO: figure out if other autocommands need ran here.
            # e.g. BufReadPost is required for syntax highlighting
            self.vim.command("doautoa BufReadPost")
            self.vim.command("doautoa BufEnter")

        # Goto the proper line and set the cursor on it
        self.jumpWin.cursor = (line, 0)
        self.cursor.set(targetBuf, line)
        self.cursor.show()
        self.vim.command("redraw")

    def queryBreakpoints(self):
        # Get the source code buffer number
        bufNum = self.jumpWin.buffer.handle

        # Get the source code file name
        fname = self.vim.call("expand", '#%d:p' % bufNum)

        # If no file name or a weird name with spaces, ignore it (to avoid
        # misinterpretation)
        if fname and fname.find(' ') == -1:
            # Query the breakpoints for the shown file
            self.breakpoint.query(bufNum, fname)
            # If there was a cursor, make sure it stays above the breakpoints.
            self.cursor.reshow()
            self.vim.command("redraw")

        # Execute the rest of custom commands
        self.vim.command("doautocmd User NvimGdbQuery")
