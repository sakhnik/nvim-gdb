
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

        -- go to the other window and spawn gdb client
        gdb.client.init(wcli, proxyCmd, clientCmd, backendStr)

        -- Initialize the windowing subsystem
        gdb.win.init(wjump)

        -- Initialize current line tracking
        @cursor = gdb.Cursor()

        -- Initialize breakpoint tracking
        @breakpoint = gdb.Breakpoint(gdb.client.getProxyAddr!)

        -- Initialize the storage
        tls\init @


    cleanup: =>
        -- Clean up the breakpoint signs
        @breakpoint\resetSigns!
        @breakpoint\cleanup!

        -- Clean up the current line sign
        @cursor\hide!

        client_buf = gdb.client.getBuf!
        gdb.client.cleanup!

        -- Free the tabpage local storage for the current tabpage.
        tls\clear!

        -- Close the windows and the tab
        tabCount = #V.list_tabs!
        if V.buf_is_loaded(client_buf)
            V.exe ("bd! " .. client_buf)
        if tabCount == #V.list_tabs!
            V.exe "tabclose"

    getCursor: =>
        @cursor

    getBreakpoint: =>
        @breakpoint

    toggleBreak: =>
        if gdb.client.isRunning()
            -- pause first
            gdb.client.interrupt()

        buf = V.cur_buf!
        fileName = GetFullBufferPath(buf)
        fileBreaks = @breakpoint\getForFile(fileName)
        lineNr = '' .. V.call("line", {"."})    -- Must be string to query from the fileBreaks

        breakId = fileBreaks[lineNr]
        if breakId != nil
            -- There already is a breakpoint on this line: remove
            gdb.client.sendLine(gdb.client.getCommand('delete_breakpoints') .. ' ' .. breakId)
        else
            gdb.client.sendLine(gdb.client.getCommand('breakpoint') .. ' ' .. fileName .. ':' .. lineNr)

    clearBreaks: =>
        if gdb.client.isRunning()
            -- pause first
            gdb.client.interrupt()

        -- The breakpoint signs will be requeried later automatically
        gdb.client.sendLine(gdb.client.getCommand('delete_breakpoints'))

    tabEnter: =>
        -- Restore the signs as they may have been spoiled
        if gdb.client.isPaused!
            @cursor\show!

        -- Ensure breakpoints are shown if are queried dynamically
        gdb.win.queryBreakpoints!

    tabLeave: =>
        -- Hide the signs
        @cursor\hide()
        @breakpoint\clearSigns!


-- Dispatch a call to the current tabpage-specific
-- instance of the application.
Dispatch = (name, ...) ->
    app = tls\get!
    if app
        App.__base[name](app, ...)

ret =
    init: App
    cleanup: -> Dispatch("cleanup")
    getFullBufferPath: GetFullBufferPath
    checkTab: CheckTab
    dispatch: Dispatch

ret
