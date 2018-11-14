
proxyAddr = V.def_tvar("gdb_client_proxy_addr")
clientId = V.def_tvar("gdb_client_id")
clientBuf = V.def_tvar("gdb_client_buf")

fmt = string.format

Init = (win, proxy_cmd, client_cmd) ->
    -- Prepare the debugger command to run
    command = client_cmd
    if proxy_cmd != ''
        proxyAddr.set(V.call("tempname", {}))
        command = fmt("%s/lib/%s -a %s -- %s",
            V.call("nvimgdb#GetPluginDir", {}), proxy_cmd, proxyAddr.get!,
            client_cmd)

    -- Go to the yet-to-be terminal window
    V.exe fmt("%dwincmd w", V.win_get_nr(win))

    clientId.set(V.call("nvimgdb#TermOpen", {command, V.cur_tab!}))
    clientBuf.set(V.cur_buf!)

Interrupt = ->
    V.call("jobsend", {clientId.get!, "\x03"})

SendLine = (data) ->
    V.call("jobsend", {clientId.get!, data .. "\n"})

ret =
    init: Init
    getBuf: clientBuf.get
    getProxyAddr: proxyAddr.get
    interrupt: Interrupt
    sendLine: SendLine

ret
