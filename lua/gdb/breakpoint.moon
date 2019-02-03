require "set_paths"
V = require "gdb.v"
json = require "JSON"

fmt = string.format


class Breakpoint
    new: (config, proxy) =>
        @config = config
        @proxy = proxy
        @breaks = {}    -- {file -> {line -> [id]}}
        @maxSignId = 0

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
        resp = @proxy\query fmt("info-breakpoints %s\n", fname)
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
