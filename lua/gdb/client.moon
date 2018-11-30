V = require "gdb.v"

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
        V.jump_win win
        V.exe "enew"
        @clientBuf = V.get_current_buf!

    cleanup: =>
        if @proxyAddr != ''
            os.remove(@proxyAddr)

    start: =>
        -- Go to the yet-to-be terminal window
        V.jump_win @win
        @clientId = V.call("nvimgdb#TermOpen", {@command, V.get_current_tabpage!})

    interrupt: =>
        V.call("jobsend", {@clientId, "\x03"})

    sendLine: (data) =>
        V.call("jobsend", {@clientId, data .. "\n"})

    getBuf: => @clientBuf
    getProxyAddr: => @proxyAddr

Client
