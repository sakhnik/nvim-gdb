
fmt = string.format

-- Tabpage local storage
tls = V.def_tstorage!

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

        @backend = gdb.backend[backendStr]
        @scm = gdb.scm.init(@backend)

        -- go to the other window and spawn gdb client
        @client = gdb.Client(wcli, proxyCmd, clientCmd)

        -- Initialize the windowing subsystem
        gdb.win.init(wjump)

        -- Initialize current line tracking
        @cursor = gdb.Cursor()

        -- Initialize breakpoint tracking
        @breakpoint = gdb.Breakpoint(@client\getProxyAddr!)


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

    getCursor: => @cursor
    getBreakpoint: => @breakpoint
    getClient: => @client

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
        gdb.win.queryBreakpoints!

    tabLeave: =>
        -- Hide the signs
        @cursor\hide()
        @breakpoint\clearSigns!


Init = (backendStr, proxyCmd, clientCmd) ->
    app = App backendStr, proxyCmd, clientCmd
    -- Remember the instance into the tabpage-specific storage
    tls\init app


-- Dispatch a call to the current tabpage-specific
-- instance of the application.
Dispatch = (name, ...) ->
    app = tls\get!
    if app
        App.__base[name](app, ...)

ret =
    init: Init
    cleanup: -> Dispatch("cleanup")
    getFullBufferPath: GetFullBufferPath
    checkTab: CheckTab
    dispatch: Dispatch

ret
