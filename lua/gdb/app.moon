
fmt = string.format

-- Tabpage local storage
tls = V.def_tstorage!

Init = (backendStr, proxyCmd, clientCmd) ->
    -- Create new tab for the debugging view and split horizontally
    V.exe "tabnew | sp"

    -- Enumerate the available windows
    wins = V.list_wins!
    table.sort wins
    wcli, wjump = unpack(wins)

    -- Initialize the storage
    tls\init!

    -- go to the other window and spawn gdb client
    gdb.client.init(wcli, proxyCmd, clientCmd, backendStr)

    -- Initialize the windowing subsystem
    gdb.win.init(wjump)

    -- Initialize current line tracking
    tls\set("cursor", gdb.Cursor())

    -- Initialize breakpoint tracking
    tls\set("breakpoint", gdb.Breakpoint(gdb.client.getProxyAddr!))


Cleanup = ->
    -- Clean up the breakpoint signs
    tls\get!.breakpoint\resetSigns!
    tls\get!.breakpoint\cleanup!

    -- Clean up the current line sign
    tls\get!.cursor\hide!

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

GetFullBufferPath = (bufNr) ->
    -- Breakpoints need full path to the buffer (at least in lldb)
    V.call("expand", {fmt('#%d:p', bufNr)})

ToggleBreak = ->
    if gdb.client.checkTab()
        if gdb.client.isRunning()
            -- pause first
            gdb.client.interrupt()

        buf = V.cur_buf!
        fileName = GetFullBufferPath(buf)
        fileBreaks = tls\get!.breakpoint\getForFile(fileName)
        lineNr = '' .. V.call("line", {"."})    -- Must be string to query from the fileBreaks

        breakId = fileBreaks[lineNr]
        if breakId != nil
            -- There already is a breakpoint on this line: remove
            gdb.client.sendLine(gdb.client.getCommand('delete_breakpoints') .. ' ' .. breakId)
        else
            gdb.client.sendLine(gdb.client.getCommand('breakpoint') .. ' ' .. fileName .. ':' .. lineNr)

ClearBreaks = ->
    if gdb.client.checkTab()

        if gdb.client.isRunning()
            -- pause first
            gdb.client.interrupt()

        -- The breakpoint signs will be requeried later automatically
        gdb.client.sendLine(gdb.client.getCommand('delete_breakpoints'))

TabEnter = ->
    if gdb.client.checkTab!
        -- Restore the signs as they may have been spoiled
        if gdb.client.isPaused!
            tls\get!.cursor\show!

        -- Ensure breakpoints are shown if are queried dynamically
        gdb.win.queryBreakpoints!

TabLeave = ->
    if gdb.client.checkTab()
        -- Hide the signs
        store = tls\get!
        if store
            store.cursor\hide()
        tls\get!.breakpoint\clearSigns!

ret =
    init: Init
    cleanup: Cleanup
    getFullBufferPath: GetFullBufferPath
    toggleBreak: ToggleBreak
    clearBreaks: ClearBreaks
    get: -> tls\get!
    tabLeave: TabLeave
    tabEnter: TabEnter

ret
