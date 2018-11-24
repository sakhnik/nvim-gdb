Client = require "gdb.client"
Cursor = require "gdb.cursor"
Breakpoint = require "gdb.breakpoint"
Win = require "gdb.win"
Keymaps = require "gdb.keymaps"

fmt = string.format

-- A table attached to a tabpage
class TStorage
    new: => @data = {}
    init: (v) => @data[V.cur_tab!] = v      -- Create a tabpage-specific table
    get: => @data[V.cur_tab!]               -- Access the table for the current page
    getTab: (t) => @data[t]                 -- Access the table for given page
    clear: => @data[V.cur_tab!] = nil       -- Delete the tabpage-specific table

-- Tabpage local storage
tls = TStorage()

-- Prepare keymaps configuration
keymaps = Keymaps!

CheckTab = ->
    tls\get! != nil

GetFullBufferPath = (bufNr) ->
    -- Breakpoints need full path to the buffer (at least in lldb)
    V.call("expand", {fmt('#%d:p', bufNr)})


class App
    new: (backendStr, proxyCmd, clientCmd) =>
        -- Create new tab for the debugging view and split horizontally
        V.exe "tabnew | sp"

        -- Enumerate the available windows
        wins = V.list_wins!
        table.sort wins
        wcli, wjump = unpack(wins)

        @backend = require "gdb.backend." .. backendStr

        -- go to the other window and spawn gdb client
        @client = Client(wcli, proxyCmd, clientCmd)

        -- Initialize current line tracking
        @cursor = Cursor()

        -- Initialize breakpoint tracking
        @breakpoint = Breakpoint(@client\getProxyAddr!)

        -- Initialize the windowing subsystem
        @win = Win(wjump, @client, @cursor, @breakpoint)

        -- Initialize the SCM
        @scm = @backend\initScm(@cursor, @win)

        -- The SCM should be ready by now, spawn the debugger!
        @client\start!

        -- Remember the instance into the tabpage-specific storage
        tls\init @


    cleanup: =>
        -- Clean up the breakpoint signs
        @breakpoint\resetSigns!
        @breakpoint\cleanup!

        -- Clean up the current line sign
        @cursor\hide!

        -- Free the tabpage local storage for the current tabpage.
        tls\clear!

        -- Close the windows and the tab
        tabCount = #V.list_tabs!
        clientBuf = @client\getBuf!
        if V.buf_is_loaded(clientBuf)
            V.exe ("bd! " .. clientBuf)
        if tabCount == #V.list_tabs!
            V.exe "tabclose"

    getCommand: (cmd) =>
        c = @backend[cmd]
        c and c or cmd

    onStdout: (j,d,e) =>
        for _, v in ipairs(d)
            @scm\feed(v)

    send: (data) =>
        @client\sendLine(@getCommand(data))

    interrupt: => @client\interrupt!

    toggleBreak: =>
        if @scm\isRunning()
            -- pause first
            @client\interrupt()

        buf = V.cur_buf!
        fileName = GetFullBufferPath(buf)
        fileBreaks = @breakpoint\getForFile(fileName)
        lineNr = '' .. V.call("line", {"."})    -- Must be string to query from the fileBreaks

        breakId = fileBreaks[lineNr]
        if breakId != nil
            -- There already is a breakpoint on this line: remove
            @client\sendLine(@getCommand('delete_breakpoints') .. ' ' .. breakId)
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
        if V.get_buf_option(V.cur_buf!, 'buftype') != 'terminal'
            -- Make sure the cursor stays visible at all times
            V.exe "if !&scrolloff | setlocal scrolloff=5 | endif"
            keymaps\dispatchSet!
            -- Ensure breakpoints are shown if are queried dynamically
            @win\queryBreakpoints!

    onBufLeave: =>
        if V.get_buf_option(V.cur_buf!, 'buftype') != 'terminal'
            keymaps\dispatchUnset!

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
    keymaps: keymaps

-- Allow calling object functions by dispatching
-- to the tabpage local instance.
for k, v in pairs(App.__base)
    if type(v) == "function" and ret[k] == nil
        ret[k] = (...) -> Dispatch(k, ...)

ret
