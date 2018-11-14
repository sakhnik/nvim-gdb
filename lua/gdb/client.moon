
proxyAddr = V.def_tvar("gdb_client_proxy_addr")
clientId = V.def_tvar("gdb_client_id")
clientBuf = V.def_tvar("gdb_client_buf")

tst = V.def_tstorage!

fmt = string.format

Init = (win, proxy_cmd, client_cmd, backend) ->
    tst\init!
    b = gdb.backend[backend]
    tst\set("backend", b)
    tst\set("scm", gdb.scm.init(b))

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

Cleanup = ->
    tst\clear!

OnStdout = (j,d,e) ->
    s = tst\get!
    if s
        scm = s.scm
        for _, v in ipairs(d)
            scm\feed(v)

Interrupt = ->
    V.call("jobsend", {clientId.get!, "\x03"})

SendLine = (data) ->
    V.call("jobsend", {clientId.get!, data .. "\n"})

GetCommand = (cmd) ->
    c = tst\get!.backend[cmd]
    c and c or cmd

ret =
    init: Init
    cleanup: Cleanup
    onStdout: OnStdout
    getCommand: GetCommand
    getBuf: clientBuf.get
    getProxyAddr: proxyAddr.get
    interrupt: Interrupt
    sendLine: SendLine
    isPaused: -> tst\get!.scm\isPaused!
    isRunning: -> tst\get!.scm\isRunning!

ret
