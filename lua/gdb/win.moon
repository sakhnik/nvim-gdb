
jumpWin = V.def_tvar("gdb_win_jump_window")
curBuf = V.def_tvar("gdb_win_current_buf")

fmt = string.format

Init = ->
    -- window number that will be displaying the current file
    jumpWin.set(V.cur_win!)
    curBuf.set(-1)

Cleanup = ->
    gdb.breakpoint.disconnect(gdb.client.getProxyAddr!)

Jump = (file, line) ->
    window = V.cur_winnr!
    V.cmd(fmt("%dwincmd w", V.win_get_nr(jumpWin.get!)))
    curBuf.set(V.cur_buf!)
    target_buf = V.call("bufnr", {file, 1})
    if target_buf == gdb.client.getBuf!
        -- The terminal buffer may contain the name of the source file (in pdb, for
        -- instance)
        V.call("e " .. file)
        target_buf = V.call("bufnr", {file})

    if V.call("bufnr", {'%'}) != target_buf
        -- Switch to the new buffer
        V.cmd('buffer ' .. target_buf)
        curBuf.set(target_buf)
        gdb.breakpoint.refreshSigns(curBuf.get())

    V.cmd(':' .. line)
    gdb.cursor.set(line)
    V.cmd(fmt('%swincmd w', window))
    gdb.cursor.display(1)

QueryBreakpoints = ->
    -- Get the source code buffer number
    bufnum = V.win_get_buf(jumpWin.get!)

    -- Get the source code file name
    fname = V.call("nvimgdb#GetFullBufferPath", {bufnum})

    -- If no file name or a weird name with spaces, ignore it (to avoid
    -- misinterpretation)
    if fname != '' and fname\find(' ') == nil
        -- Query the breakpoints for the shown file
        gdb.breakpoint.query(bufnum, fname, gdb.client.getProxyAddr!)
        gdb.cursor.display(1)

ret = {
    init: Init
    cleanup: Cleanup
    getCurrentBuffer: curBuf.get
    jump: Jump
    queryBreakpoints: QueryBreakpoints
}

ret
