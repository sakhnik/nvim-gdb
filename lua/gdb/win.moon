
jumpWin = V.def_tvar("gdb_win_jump_window")
curBuf = V.def_tvar("gdb_win_current_buf")

fmt = string.format

Init = (win) ->
    -- window number that will be displaying the current file
    jumpWin.set(win)
    curBuf.set(-1)

Jump = (file, line) ->
    window = V.cur_winnr!
    V.exe fmt("%dwincmd w", V.win_get_nr(jumpWin.get!))
    curBuf.set(V.cur_buf!)
    target_buf = V.call("bufnr", {file, 1})
    if target_buf == gdb.app.dispatch("getClient")\getBuf!
        -- The terminal buffer may contain the name of the source file (in pdb, for
        -- instance)
        V.call("e " .. file)
        target_buf = V.call("bufnr", {file})

    if V.call("bufnr", {'%'}) != target_buf
        -- Switch to the new buffer
        V.exe ('buffer ' .. target_buf)
        curBuf.set(target_buf)
        gdb.app.dispatch("getBreakpoint")\refreshSigns(curBuf.get!)

    V.exe (':' .. line)
    gdb.app.dispatch("getCursor")\set(target_buf, line)
    V.exe fmt('%swincmd w', window)
    gdb.app.dispatch("getCursor")\show()

QueryBreakpoints = ->
    -- Get the source code buffer number
    bufNum = V.win_get_buf(jumpWin.get!)

    -- Get the source code file name
    fname = gdb.app.getFullBufferPath(bufNum)

    -- If no file name or a weird name with spaces, ignore it (to avoid
    -- misinterpretation)
    if fname != '' and fname\find(' ') == nil
        -- Query the breakpoints for the shown file
        gdb.app.dispatch("getBreakpoint")\query(bufNum, fname)
        gdb.app.dispatch("getCursor")\show!

ret =
    init: Init
    getCurrentBuffer: curBuf.get
    jump: Jump
    queryBreakpoints: QueryBreakpoints

ret
