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
        if self.jumpWin.buffer.handle != targetBuf:
            mode = self.vim.api.get_mode()
            prevWindow = None
            if self.jumpWin != self.vim.current.window:
                prevWindow = self.vim.current.window
                self.vim.current.window = self.jumpWin
            self.vim.command("e %s" % file)
            # TODO: figure out if other autocommands need ran here.
            # e.g. BufReadPost is required for syntax highlighting
            if prevWindow is not None:
                self.vim.current.window = prevWindow
            if mode['mode'] in "ti":
                self.vim.command("startinsert")
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

        # Execute the rest of custom commands
        self.vim.command("doautocmd User NvimGdbQuery")
