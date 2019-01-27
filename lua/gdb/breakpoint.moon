require "set_paths"
V = require "gdb.v"
s = require "posix.sys.socket"
u = require "posix.unistd"
json = require "JSON"

fmt = string.format


class Breakpoint
    new: (config, proxyAddr, sockDir) =>
        @config = config
        @proxyAddr = proxyAddr
        @sockAddr = sockDir .. "/client"
        @breaks = {}    -- {file -> {line -> [id]}}
        @maxSignId = 0

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

    doQuery: (fname) =>
        -- It takes time for the proxy to open a side channel.
        -- So we're connecting to the socket lazily during
        -- the first query.
        if @ensureConnected!
            assert s.send(@sock, fmt("info-breakpoints %s\n", fname))
            data = s.recv(@sock, 65536)
            data

    clearSigns: =>
        for i = 5000, @maxSignId
            V.exe ('sign unplace ' .. i)
        @maxSignId = 0

    setSigns: (buf) =>
        if buf != -1
            signId = 5000 - 1
            bpath = gdb.getFullBufferPath(buf)
            getSignName = (count) ->
                maxCount = #@config.sign_breakpoint
                idx = count <= maxCount and count or maxCount
                "GdbBreakpoint" .. idx
            for line,ids in pairs(@breaks[bpath] or {})
                signId += 1
                V.exe fmt('sign place %d name=%s line=%d buffer=%d',
                    signId, getSignName(#ids), line, buf)
            @maxSignId = signId

    query: (bufNum, fname) =>
        @breaks[fname] = {}
        resp = @doQuery fname
        if resp
            -- We expect the proxies to send breakpoints for a given file
            -- as a map of lines to array of breakpoint ids set in those lines.
            br = json\decode(resp)
            err = br._error
            if err
                V.exe ("echo \"Can't get breakpoints: \"" .. err)
            else
                @breaks[fname] = br
                @clearSigns!
                @setSigns bufNum
        --else
            -- TODO: notify about error

    resetSigns: =>
        @breaks = {}
        @clearSigns!

    getForFile: (fname, line) =>
        breaks = @breaks[fname] or {}
        breaks['' .. line]   -- make sure the line is a string

Breakpoint
