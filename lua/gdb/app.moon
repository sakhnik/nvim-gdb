V = require "gdb.v"
Config = require "gdb.config"
Client = require "gdb.client"
Proxy = require "gdb.proxy"
Cursor = require "gdb.cursor"
Breakpoint = require "gdb.breakpoint"
Win = require "gdb.win"
Keymaps = require "gdb.keymaps"
SockDir = require "gdb.sockdir"

fmt = string.format

-- A table attached to a tabpage
class TStorage
    new: => @data = {}
    init: (v) => @data[V.get_current_tabpage!] = v      -- Create a tabpage-specific table
    get: => @data[V.get_current_tabpage!]               -- Access the table for the current page
    getTab: (t) => @data[t]                             -- Access the table for given page
    clear: => @data[V.get_current_tabpage!] = nil       -- Delete the tabpage-specific table

-- Tabpage local storage
tls = TStorage()

CheckTab = ->
    tls\get! != nil

GetFullBufferPath = (bufNr) ->
    -- Breakpoints need full path to the buffer (at least in lldb)
    V.call("expand", {fmt('#%d:p', bufNr)})

defineSigns = (config) ->
    -- Define the sign for current line the debugged program is executing.
    V.exe "sign define GdbCurrentLine text=" .. config.sign_current_line
    -- Define signs for the breakpoints.
    for i,s in ipairs(config.sign_breakpoint)
        V.exe 'sign define GdbBreakpoint' .. i .. ' text=' .. s


class App
    new: (backendStr, proxyCmd, clientCmd) =>
        -- Create new tab for the debugging view and split horizontally
        V.exe "tabnew | sp"

        -- Enumerate the available windows
        wins = V.tabpage_list_wins V.get_current_tabpage!
        table.sort wins
        wcli, wjump = unpack(wins)

        -- Prepare configuration: keymaps, hooks, parameters etc.
        @config = Config!
        defineSigns @config

        @backend = require "gdb.backend." .. backendStr

        -- Create a temporary unique directory for all the sockets.
        @sockDir = SockDir!

        -- go to the other window and spawn gdb client
        @client = Client wcli, proxyCmd, clientCmd, @sockDir\get!

        -- Initialize current line tracking
        @cursor = Cursor!

        -- Initialize connection to the side channel
        @proxy = Proxy @client\getProxyAddr!, @sockDir\get!

        -- Initialize breakpoint tracking
        @breakpoint = Breakpoint @config, @proxy

        -- Initialize the windowing subsystem
        @win = Win(wjump, @client, @cursor, @breakpoint)

        -- Initialize the SCM
        @scm = @backend.initScm(@cursor, @win)

        -- The SCM should be ready by now, spawn the debugger!
        @client\start!

        -- Remember the instance into the tabpage-specific storage
        tls\init @

        -- Set initial keymaps in the terminal window.
        @keymaps = Keymaps @config
        @keymaps\dispatchSetT!
        @keymaps\dispatchSet!

        -- Start insert mode in the GDB window
        V.exe "normal i"


    cleanup: =>
        -- Clean up the breakpoint signs
        @breakpoint\resetSigns!

        -- Clean up the current line sign
        @cursor\hide!

        -- Close connection to the side channel
        @proxy\cleanup!

        -- Free the tabpage local storage for the current tabpage.
        tls\clear!

        -- Close the windows and the tab
        tabCount = #V.list_tabpages!
        clientBuf = @client\getBuf!
        if V.buf_is_loaded(clientBuf)
            V.exe ("bd! " .. clientBuf)
        if tabCount == #V.list_tabpages!
            V.exe "tabclose"

        @client\cleanup!
        @sockDir\cleanup!


    getCommand: (cmd) =>
        c = @backend[cmd]
        c and c or cmd

    onStdout: (j,d,e) =>
        for _, v in ipairs(d)
            @scm\feed(v)

    send: (cmd, ...) =>
        command = fmt(@getCommand(cmd), ...)
        @client\sendLine(command)
        @lastCommand = command  -- Remember the command for testing

    getLastCommand: => @lastCommand
    getConfig: => @config
    getKeymaps: => @keymaps

    interrupt: => @client\interrupt!

    customCommand: (cmd) =>
        @proxy\query "handle-command " .. cmd

    toggleBreak: =>
        if @scm\isRunning()
            -- pause first
            @client\interrupt()

        buf = V.get_current_buf!
        fileName = GetFullBufferPath(buf)
        lineNr = V.call("line", {"."})
        breaks = @breakpoint\getForFile fileName, lineNr

        if breaks != nil and #breaks > 0
            -- There already is a breakpoint on this line: remove
            @client\sendLine(@getCommand('delete_breakpoints') .. ' ' .. breaks[#breaks])
        else
            @client\sendLine(@getCommand('breakpoint') .. ' ' .. fileName .. ':' .. lineNr)

    clearBreaks: =>
        if @scm\isRunning()
            -- pause first
            @client\interrupt()

        -- The breakpoint signs will be requeried later automatically
        @send('delete_breakpoints')

    tabEnter: =>
        -- Restore the signs as they may have been spoiled
        if @scm\isPaused!
            @cursor\show!

        -- Ensure breakpoints are shown if are queried dynamically
        @win\queryBreakpoints!

    tabLeave: =>
        -- Hide the signs
        @cursor\hide()
        @breakpoint\clearSigns!

    queryBreakpoints: =>
        @win\queryBreakpoints!

    onBufEnter: =>
        if V.buf_get_option(V.get_current_buf!, 'buftype') != 'terminal'
            -- Make sure the cursor stays visible at all times
            V.exe "if !&scrolloff | setlocal scrolloff=5 | endif"
            @keymaps\dispatchSet!
            -- Ensure breakpoints are shown if are queried dynamically
            @win\queryBreakpoints!

    onBufLeave: =>
        if V.buf_get_option(V.get_current_buf!, 'buftype') != 'terminal'
            @keymaps\dispatchUnset!

Init = (backendStr, proxyCmd, clientCmd) ->
    App backendStr, proxyCmd, clientCmd
    0  -- return a POD value to make Vim happy


-- Dispatch a call to the current tabpage-specific
-- instance of the application.
Dispatch = (name, ...) ->
    app = tls\get!
    if app
        App.__base[name](app, ...)

-- Dispatch client stdout output to it's tabpage's SCM
OnStdout = (tab, j, d, e) ->
    app = tls\getTab tab
    app\onStdout(j, d, e)

ret =
    init: Init
    getFullBufferPath: GetFullBufferPath
    checkTab: CheckTab
    onStdout: OnStdout

-- Allow calling object functions by dispatching
-- to the tabpage local instance.
for k, v in pairs(App.__base)
    if type(v) == "function" and ret[k] == nil
        ret[k] = (...) -> Dispatch(k, ...)

ret
