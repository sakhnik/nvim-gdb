V = require "gdb.v"

fmt = string.format

class Win
    new: (win, client, cursor, breakpoint) =>
        -- window number that will be displaying the current file
        @jumpWin = win
        @client = client
        @cursor = cursor
        @breakpoint = breakpoint

    jump: (file, line) =>
        -- Make sure all the operations happen in the correct window
        window = V.get_current_win!
        V.jump_win @jumpWin

        -- Check whether the file is already loaded or load it
        targetBuf = V.call("bufnr", {file, 1})

        -- The terminal buffer may contain the name of the source file (in pdb, for
        -- instance)
        if targetBuf == @client\getBuf!
            V.exe "noswapfile view " .. file
            targetBuf = V.call("bufnr", {file})

        -- Switch to the new buffer if necessary
        if V.call("bufnr", {'%'}) != targetBuf
            V.exe 'noswapfile buffer ' .. targetBuf

        -- Goto the proper line and set the cursor on it
        V.exe ':' .. line
        @cursor\set(targetBuf, line)
        @cursor\show!

        -- Return to the original window for the user
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
            -- If there was a cursor, make sure it stays above the breakpoints.
            @cursor\reshow!

Win
