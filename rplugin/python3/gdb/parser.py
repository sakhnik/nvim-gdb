"""State machine for handing debugger output."""

from gdb.common import Common
from gdb.backend.base import ParserHandler


class ParserAdapter(Common, ParserHandler):
    """Common FSM implementation for the integrated backends."""

    def __init__(self, common, win):
        """ctor."""
        Common.__init__(self, common)
        self.win = win

    def continue_program(self):
        """Handle the program continued execution. Hide the cursor."""
        self.vim.exec_lua("nvimgdb.i().cursor:hide()")
        self.vim.command("doautocmd User NvimGdbContinue")

    def jump_to_source(self, fname: str, line: int):
        """Handle the program breaked. Show the source code."""
        self.win.jump(fname, line)
        self.vim.command("doautocmd User NvimGdbBreak")

    def query_breakpoints(self):
        """It's high time to query actual breakpoints."""
        self.win.query_breakpoints()
        # Execute the rest of custom commands
        self.vim.command("doautocmd User NvimGdbQuery")
