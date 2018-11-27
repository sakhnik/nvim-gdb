
fmt = string.format

class Client
    new: (win, proxyCmd, clientCmd, sockDir) =>
        @win = win

        -- Prepare the debugger command to run
        @command = clientCmd
        if proxyCmd != ''
            @proxyAddr = sockDir .. '/server'
            @command = fmt("%s/lib/%s -a %s -- %s",
                V.call("nvimgdb#GetPluginDir", {}), proxyCmd, @proxyAddr, clientCmd)
        V.jump_win V.win_get_nr(win)
        V.exe "enew"
        @clientBuf = V.cur_buf!

    cleanup: =>
        if @proxyAddr != ''
            os.remove(@proxyAddr)

    start: =>
        -- Go to the yet-to-be terminal window
        V.jump_win V.win_get_nr(@win)
        @clientId = V.call("nvimgdb#TermOpen", {@command, V.cur_tab!})

    interrupt: =>
        V.call("jobsend", {@clientId, "\x03"})

    sendLine: (data) =>
        V.call("jobsend", {@clientId, data .. "\n"})

    getBuf: => @clientBuf
    getProxyAddr: => @proxyAddr

Client
