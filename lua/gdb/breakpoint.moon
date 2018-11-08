require "set_paths"
libstd = require "posix.stdlib"
s = require "posix.sys.socket"
u = require "posix.unistd"

clientSet = {}

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

BreakpointQuery = (fname, proxy_addr) ->
    sock = GetSocket proxy_addr
    s.send(sock, "info-breakpoints " .. fname .. "\n")
    data = s.recv(sock, 65536)
    data

BreakpointDisconnect = (proxy_addr) ->
    data = clientSet[proxy_addr]
    if data != nil
        u.close(data[1])
        os.remove(data[2] .. "/socket")
        os.remove(data[2])
        clientSet[proxy_addr] = nil

ret = {
    query: BreakpointQuery,
    disconnect: BreakpointDisconnect,
}
ret
