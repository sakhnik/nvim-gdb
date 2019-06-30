from pynvim import NvimError
class Win:
    def __init__(self, vim, logger, win, cursor, client, breakpoint, keymaps):
        self.vim = vim
        self.log = lambda msg: logger.log('win', msg)
        # window number that will be displaying the current file
        self.jumpWin = win
        self.cursor = cursor
        self.client = client
        self.breakpoint = breakpoint
        self.keymaps = keymaps

    # Check whether the current buffer is displayed in the jump window
    def isJumpWindowActive(self):
        return self.vim.current.buffer == self.jumpWin.buffer

    def jump(self, file, line):
        # Check whether the file is already loaded or load it
        targetBuf = self.vim.call("bufnr", file, 1)
        # The terminal buffer may contain the name of the source file (in pdb, for
        # instance)
        if targetBuf == self.client.get_buf().handle:
            self.vim.command("noswapfile view " + file)
            targetBuf = self.vim.call("bufnr", file)
        if self.jumpWin.buffer.handle != targetBuf:
            try:
                # This file being opened having a .swp file causes this function to throw
                self.vim.call("nvim_win_set_buf", self.jumpWin.handle, targetBuf)
            except NvimError as e:
                self.log('Exception: {}'.format(str(e)))
            # TODO: figure out if other autocommands need ran here.
            # e.g. BufReadPost is required for syntax highlighting
            self.vim.command("doautoa BufReadPost")
            self.queryBreakpoints()

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
