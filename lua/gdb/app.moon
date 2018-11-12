
Init = (backendStr, proxyCmd, clientCmd) ->
    -- Create new tab for the debugging view and split horizontally
    V.cmd("tabnew | sp")

    -- Enumerate the available windows
    wins = V.list_wins!
    table.sort wins
    wcli, wjump = unpack(wins)

    -- TODO: restore
    --if !&scrolloff
    -- Make sure the cursor stays visible at all times
    --  setlocal scrolloff=5

    -- Initialize the windowing subsystem
    gdb.win.init(wjump)

    -- Initialize current line tracking
    gdb.cursor.init!

    -- Initialize breakpoint tracking
    gdb.breakpoint.init!

    -- go to the other window and spawn gdb client
    gdb.client.init(wcli, proxyCmd, clientCmd, backendStr)

ret =
    init: Init

ret
