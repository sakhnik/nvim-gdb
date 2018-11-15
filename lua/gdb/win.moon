
fmt = string.format

class Win
    new: (win, client, cursor, breakpoint) =>
        -- window number that will be displaying the current file
        @jumpWin = win
        @curBuf = -1
        @client = client
        @cursor = cursor
        @breakpoint = breakpoint

    jump: (file, line) =>
        window = V.cur_winnr!
        V.exe fmt("%dwincmd w", V.win_get_nr(@jumpWin))
        @curBuf = V.cur_buf!
        targetBuf = V.call("bufnr", {file, 1})
        if targetBuf == @client\getBuf!
            -- The terminal buffer may contain the name of the source file (in pdb, for
            -- instance)
            V.call("e " .. file)
            targetBuf = V.call("bufnr", {file})

        if V.call("bufnr", {'%'}) != targetBuf
            -- Switch to the new buffer
            V.exe ('buffer ' .. targetBuf)
            @curBuf = targetBuf
            @breakpoint\refreshSigns(@curBuf)

        V.exe (':' .. line)
        @cursor\set(targetBuf, line)
        V.exe fmt('%swincmd w', window)
        @cursor\show()

    queryBreakpoints: =>
        -- Get the source code buffer number
        bufNum = V.win_get_buf(@jumpWin)

        -- Get the source code file name
        fname = gdb.app.getFullBufferPath(bufNum)

        -- If no file name or a weird name with spaces, ignore it (to avoid
        -- misinterpretation)
        if fname != '' and fname\find(' ') == nil
            -- Query the breakpoints for the shown file
            @breakpoint\query(bufNum, fname)
            @cursor\show!

Win
