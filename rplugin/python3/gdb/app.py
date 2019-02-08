from gdb.cursor import Cursor
from gdb.sockdir import SockDir
from gdb.client import Client
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

#CheckTab = ->
#    tls\get! != nil
#
#GetFullBufferPath = (bufNr) ->
#    -- Breakpoints need full path to the buffer (at least in lldb)
#    V.call("expand", {fmt('#%d:p', bufNr)})
#
#defineSigns = (config) ->
#    -- Define the sign for current line the debugged program is executing.
#    V.exe "sign define GdbCurrentLine text=" .. config.sign_current_line
#    -- Define signs for the breakpoints.
#    for i,s in ipairs(config.sign_breakpoint)
#        V.exe 'sign define GdbBreakpoint' .. i .. ' text=' .. s


#ret =
#    init: Init
#    getFullBufferPath: GetFullBufferPath
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

        ##-- Prepare configuration: keymaps, hooks, parameters etc.
        ##@config = Config!
        ##defineSigns @config

        # Import the desired backend module
        self.backend = importlib.import_module("gdb.backend." + backendStr).init()

        # Create a temporary unique directory for all the sockets.
        self.sockDir = SockDir()

        # Initialize current line tracking
        self.cursor = Cursor(vim)

        # Initialize the SCM
        self.scm = self.backend["initScm"](vim, self.cursor)

        # Go to the other window and spawn gdb client
        self.client = Client(vim, wcli, proxyCmd, clientCmd, self.sockDir)

        #-- Initialize connection to the side channel
        #@proxy = Proxy @client\getProxyAddr!, sockDir

        #-- Initialize breakpoint tracking
        #@breakpoint = Breakpoint @config, @proxy

        #-- Initialize the windowing subsystem
        #@win = Win(wjump, @client, @breakpoint)

        #-- Set initial keymaps in the terminal window.
        #@keymaps = Keymaps @config
        #@keymaps\dispatchSetT!
        #@keymaps\dispatchSet!

        #-- Start insert mode in the GDB window
        #V.exe "normal i"

    def start(self):
        # The SCM should be ready by now, spawn the debugger!
        self.client.start()

    def cleanup(self):
#        -- Clean up the breakpoint signs
#        @breakpoint\resetSigns!
#
        # Clean up the current line sign
        self.cursor.hide()
#
#        -- Close connection to the side channel
#        @proxy\cleanup!
#
        # Close the windows and the tab
        tabCount = len(self.vim.tabpages)
        self.client.delBuffer()
        if tabCount == len(self.vim.tabpages):
            self.vim.command("tabclose")

        self.client.cleanup()
        self.sockDir.cleanup()

    def getCommand(self, cmd):
        return self.backend.get(cmd, cmd)

#    send: (cmd, ...) =>
#        command = fmt(@getCommand(cmd), ...)
#        @client\sendLine(command)
#        @lastCommand = command  -- Remember the command for testing
#
#    getLastCommand: => @lastCommand
#    getConfig: => @config
#    getKeymaps: => @keymaps
#    getWin: => @win
#
#    interrupt: => @client\interrupt!
#
#    customCommand: (cmd) =>
#        @proxy\query "handle-command " .. cmd
#
#    toggleBreak: =>
#        if V.gdb_py {"dispatch", "scm", "isRunning"}
#            -- pause first
#            @client\interrupt()
#
#        buf = V.get_current_buf!
#        fileName = GetFullBufferPath(buf)
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

        ## Ensure breakpoints are shown if are queried dynamically
        #@win\queryBreakpoints!

    def onTabLeave(self):
        # Hide the signs
        self.cursor.hide()
        #self.breakpoint.clearSigns()

    def onBufEnter(self):
        pass
        #if V.buf_get_option(V.get_current_buf!, 'buftype') != 'terminal'
        #    # Make sure the cursor stays visible at all times
        #    V.exe "if !&scrolloff | setlocal scrolloff=5 | endif"
        #    @keymaps\dispatchSet!
        #    # Ensure breakpoints are shown if are queried dynamically
        #    @win\queryBreakpoints!

    def onBufLeave(self):
        pass
        #if V.buf_get_option(V.get_current_buf!, 'buftype') != 'terminal'
        #    @keymaps\dispatchUnset!

    def dispatch(self, params):
        obj = getattr(self, params[0])
        method = getattr(obj, params[1])
        params = params[2:]
        return method(*params)
