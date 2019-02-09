from gdb.config import getConfig
from gdb.cursor import Cursor
from gdb.sockdir import SockDir
from gdb.client import Client
from gdb.win import Win
from gdb.keymaps import Keymaps
from gdb.proxy import Proxy
from gdb.breakpoint import Breakpoint
import importlib


#class Context:
#    def __init__(self, vim):
#        self.vim = vim
#        self.f = None
#        self.f = open("/tmp/nvimgdb.log", "w")
#
#    def log(self, msg):
#        if self.f:
#            self.f.write("%s\n" % msg)
#            self.f.flush()


#ret =
#    init: Init
#
#-- Allow calling object functions by dispatching
#-- to the tabpage local instance.
#for k, v in pairs(App.__base)
#    if type(v) == "function" and ret[k] == nil
#        ret[k] = (...) -> Dispatch(k, ...)

class App:
    def __init__(self, vim, backendStr, proxyCmd, clientCmd):
        self.vim = vim

        # Create new tab for the debugging view and split horizontally
        vim.command("tabnew | sp")

        # Enumerate the available windows
        wins = vim.current.tabpage.windows
        wcli, wjump = wins[1], wins[0]

        # Prepare configuration: keymaps, hooks, parameters etc.
        self.config = getConfig()
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
        self.scm = self.backend["initScm"](vim, self.cursor, self.win)

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

    def send(self, cmd, *args):
        if cmd:
            command = self.backend.get(cmd, cmd).format(args)
            self.client.sendLine(command)
            self.lastCommand = command  # Remember the command for testing
        else:
            self.client.interrupt()

#    getLastCommand: => @lastCommand
#    getConfig: => @config
#    getKeymaps: => @keymaps
#    getWin: => @win

    def customCommand(self, cmd):
        return self.proxy.query("handle-command " + cmd)

#    toggleBreak: =>
#        if V.gdb_py {"dispatch", "scm", "isRunning"}
#            -- pause first
#            @client\interrupt()
#
#        buf = V.get_current_buf!
#        fileName = self.vim.call("expand", '#%d:p' % buf)
#        lineNr = V.call("line", {"."})
#        breaks = @breakpoint\getForFile fileName, lineNr
#
#        if breaks != nil and #breaks > 0
#            -- There already is a breakpoint on this line: remove
#            @client\sendLine(@getCommand('delete_breakpoints') .. ' ' .. breaks[#breaks])
#        else
#            @client\sendLine(@getCommand('breakpoint') .. ' ' .. fileName .. ':' .. lineNr)
#
#    clearBreaks: =>
#        if V.gdb_py {"dispatch", "scm", "isRunning"}
#            -- pause first
#            @client\interrupt()
#
#        -- The breakpoint signs will be requeried later automatically
#        @send('delete_breakpoints')

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
            pass
        #    @keymaps\dispatchUnset!

    def dispatch(self, params):
        obj = getattr(self, params[0])
        method = getattr(obj, params[1])
        params = params[2:]
        return method(*params)

