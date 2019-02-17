from gdb.config import getConfig
from gdb.cursor import Cursor
from gdb.sockdir import SockDir
from gdb.client import Client
from gdb.win import Win
from gdb.keymaps import Keymaps
from gdb.proxy import Proxy
from gdb.breakpoint import Breakpoint
import importlib
import os


class App:
    def __init__(self, vim, logger, backendStr, proxyCmd, clientCmd):
        self.vim = vim
        self.log = lambda msg: logger.log('app', msg)

        # Create new tab for the debugging view and split horizontally
        vim.command("tabnew | sp")

        # Enumerate the available windows
        wins = vim.current.tabpage.windows
        wcli, wjump = wins[1], wins[0]

        # Prepare configuration: keymaps, hooks, parameters etc.
        self.config = getConfig(vim)
        self.defineSigns(self.config)

        # Import the desired backend module
        self.backend = importlib.import_module("gdb.backend." + backendStr).init()

        # Create a temporary unique directory for all the sockets.
        self.sockDir = SockDir()

        # Initialize current line tracking
        self.cursor = Cursor(vim)

        # Go to the other window and spawn gdb client
        self.client = Client(vim, wcli, proxyCmd, clientCmd, self.sockDir)

        # Initialize connection to the side channel
        self.proxy = Proxy(vim, self.client.getProxyAddr(), self.sockDir)

        # Initialize breakpoint tracking
        self.breakpoint = Breakpoint(vim, self.config, self.proxy)

        # Initialize the windowing subsystem
        self.win = Win(vim, wjump, self.cursor, self.client, self.breakpoint)

        # Initialize the SCM
        self.scm = self.backend["initScm"](vim, logger, self.cursor, self.win)

        # Set initial keymaps in the terminal window.
        self.keymaps = Keymaps(vim, self.config)
        self.keymaps.dispatchSetT()
        self.keymaps.dispatchSet()

        # Start insert mode in the GDB window
        vim.feedkeys("i")

    def start(self):
        # The SCM should be ready by now, spawn the debugger!
        self.client.start()

    def cleanup(self):
        # Clean up the breakpoint signs
        self.breakpoint.resetSigns()

        # Clean up the current line sign
        self.cursor.hide()

        # Close connection to the side channel
        self.proxy.cleanup()

        # Close the windows and the tab
        tabCount = len(self.vim.tabpages)
        self.client.delBuffer()
        if tabCount == len(self.vim.tabpages):
            self.vim.command("tabclose")

        self.client.cleanup()
        self.sockDir.cleanup()

    def defineSigns(self, config):
        # Define the sign for current line the debugged program is executing.
        self.vim.command("sign define GdbCurrentLine text=" + config["sign_current_line"])
        # Define signs for the breakpoints.
        breaks = config["sign_breakpoint"]
        for i in range(len(breaks)):
            self.vim.command('sign define GdbBreakpoint%d text=%s' % ((i+1), breaks[i]))

    def getCommand(self, cmd):
        return self.backend.get(cmd, cmd)

    def send(self, *args):
        if args:
            command = self.backend.get(args[0], args[0]).format(*args[1:])
            self.client.sendLine(command)
            self.lastCommand = command  # Remember the command for testing
        else:
            self.client.interrupt()

    def customCommand(self, cmd):
        return self.proxy.query("handle-command " + cmd)

    def breakpointToggle(self):
        if self.scm.isRunning():
            # pause first
            self.client.interrupt()
        buf = self.vim.current.buffer
        fileName = self.vim.call("expand", '#%d:p' % buf.handle)
        lineNr = self.vim.call("line", ".")
        breaks = self.breakpoint.getForFile(fileName, lineNr)

        if breaks:
            # There already is a breakpoint on this line: remove
            self.client.sendLine("%s %d" % (self.getCommand('delete_breakpoints'), breaks[-1]))
        else:
            self.client.sendLine("%s %s:%s" % (self.getCommand('breakpoint'), fileName, lineNr))

    def breakpointClearAll(self):
        if self.scm.isRunning():
            # pause first
            self.client.interrupt()
        # The breakpoint signs will be requeried later automatically
        self.send('delete_breakpoints')

    def onTabEnter(self):
        # Restore the signs as they may have been spoiled
        if self.scm.isPaused():
            self.cursor.show()
        # Ensure breakpoints are shown if are queried dynamically
        self.win.queryBreakpoints()

    def onTabLeave(self):
        # Hide the signs
        self.cursor.hide()
        self.breakpoint.clearSigns()

    def onBufEnter(self):
        if self.vim.current.buffer.options['buftype'] != 'terminal':
            # Make sure the cursor stay visible at all times
            self.vim.command("if !&scrolloff | setlocal scrolloff=5 | endif")
            self.keymaps.dispatchSet()
            # Ensure breakpoints are shown if are queried dynamically
            self.win.queryBreakpoints()

    def onBufLeave(self):
        if self.vim.current.buffer.options['buftype'] != 'terminal':
            self.keymaps.dispatchUnset()
