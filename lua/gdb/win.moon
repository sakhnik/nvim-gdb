
fmt = string.format

class Win
    new: (win, client, cursor, breakpoint) =>
        -- window number that will be displaying the current file
        @jumpWin = win
        @client = client
        @cursor = cursor
        @breakpoint = breakpoint

    jump: (file, line) =>
        window = V.get_current_win!
        V.jump_win @jumpWin
        curBuf = V.cur_buf!
        targetBuf = V.call("bufnr", {file, 1})
        if targetBuf == @client\getBuf!
            -- The terminal buffer may contain the name of the source file (in pdb, for
            -- instance)
            V.exe ("noswapfile view " .. file)
            targetBuf = V.call("bufnr", {file})

        if V.call("bufnr", {'%'}) != targetBuf
            -- Switch to the new buffer
            V.exe ('noswapfile buffer ' .. targetBuf)
            curBuf = targetBuf
            @breakpoint\refreshSigns(curBuf)

        V.exe (':' .. line)
        @cursor\set(targetBuf, line)
        @cursor\show()
        V.jump_win window

    queryBreakpoints: =>
        -- Get the source code buffer number
        bufNum = V.win_get_buf(@jumpWin)

        -- Get the source code file name
        fname = gdb.getFullBufferPath(bufNum)

        -- If no file name or a weird name with spaces, ignore it (to avoid
        -- misinterpretation)
        if fname != '' and fname\find(' ') == nil
            -- Query the breakpoints for the shown file
            @breakpoint\query(bufNum, fname)
            -- If there were a cursor, make sure it stays above the breakpoints.
            @cursor\reshow!

Win
