require "set_paths"
libstd = require "posix.stdlib"
s = require "posix.sys.socket"
u = require "posix.unistd"
json = require "JSON"

clientSet = {}

breaks = V.def_tstorage()  -- tabpage -> {file -> {line -> id}}}

max_sign_id = V.def_tvar("gdb_breakpoint_max_sign_id")

fmt = string.format


GetSocket = (proxy_addr) ->
    data = clientSet[proxy_addr]
    if data != nil
        data[1]
    else
        dir = libstd.mkdtemp('/tmp/nvimgdb-sock-XXXXXX')
        sock = s.socket(s.AF_UNIX, s.SOCK_DGRAM, 0)
        s.bind(sock, {family: s.AF_UNIX, path: dir .. "/socket"})
        s.setsockopt(sock, s.SOL_SOCKET, s.SO_RCVTIMEO, 0, 500000)
        s.connect(sock, {family: s.AF_UNIX, path: proxy_addr})
        clientSet[proxy_addr] = {sock, dir}
        sock

DoQuery = (fname, proxy_addr) ->
    sock = GetSocket proxy_addr
    s.send(sock, fmt("info-breakpoints %s\n", fname))
    data = s.recv(sock, 65536)
    data

Disconnect = (proxy_addr) ->
    data = clientSet[proxy_addr]
    if data != nil
        u.close(data[1])
        os.remove(data[2] .. "/socket")
        os.remove(data[2])
        clientSet[proxy_addr] = nil
    -- TODO: move to a proper destructor
    breaks\clear!


ClearSigns = ->
    for i = 5000, max_sign_id.get()
        V.cmd('sign unplace ' .. i)
    max_sign_id.set(0)

SetSigns = (buf) ->
    if buf != -1
        sign_id = 5000 - 1
        bpath = V.call("nvimgdb#GetFullBufferPath", {buf})
        for line, _ in pairs(breaks\get![bpath] or {})
            sign_id += 1
            V.cmd(fmt('sign place %d name=GdbBreakpoint line=%d buffer=%d', sign_id, line, buf))
        max_sign_id.set(sign_id)

RefreshSigns = (buf) ->
    ClearSigns()
    SetSigns(buf)

Init = ->
    breaks\init!
    max_sign_id.set(0)

Query = (bufnum, fname, proxy_addr) ->
    resp = DoQuery(fname, proxy_addr)
    br = json\decode(resp)
    err = br._error
    if err
        V.cmd("echo \"Can't get breakpoints: \"" .. err)
    else
        breaks\set(fname, br)
        RefreshSigns(bufnum)

CleanupSigns = ->
    breaks\init!
    ClearSigns!

GetForFile = (fname) ->
    breaks\get![fname] or {}

ret = {
    init: Init,
    query: Query,
    refreshSigns: RefreshSigns,
    clearSigns: ClearSigns,
    cleanupSigns: CleanupSigns,
    disconnect: Disconnect,
    getForFile: GetForFile,
}

ret
