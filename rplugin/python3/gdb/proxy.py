require "set_paths"
s = require "posix.sys.socket"
u = require "posix.unistd"


class Proxy
    new: (proxyAddr, sockDir) =>
        @proxyAddr = proxyAddr
        @sockAddr = sockDir .. "/client"

        @sock = s.socket(s.AF_UNIX, s.SOCK_DGRAM, 0)
        assert(@sock != -1)
        assert(s.bind(@sock, {family: s.AF_UNIX, path: @sockAddr}))
        assert(s.setsockopt(@sock, s.SOL_SOCKET, s.SO_RCVTIMEO, 0, 500000))
        -- Will connect to the socket later, when the first query is needed
        -- to be issued.
        @connected = false

    cleanup: =>
        if @sock != -1
            u.close(@sock)
        os.remove @sockAddr

    ensureConnected: =>
        if not @connected
            ret, msg, err = s.connect(@sock, {family: s.AF_UNIX, path: @proxyAddr})
            if msg
                print "Breakpoint: not connected to the proxy: "..msg
            @connected = ret == 0
        @connected

    query: (request) =>
        -- It takes time for the proxy to open a side channel.
        -- So we're connecting to the socket lazily during
        -- the first query.
        if @ensureConnected!
            assert s.send(@sock, request)
            data = s.recv(@sock, 65536)
            data

Proxy
