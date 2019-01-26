Session = require "nvim.session"
ChildProcessStream = require "nvim.child_process_stream"
TcpStream = require "nvim.tcp_stream"
luv = require "luv"


-- Neovim proxy
class Engine

    new: =>
        addrPort = os.getenv 'NVIM_LISTEN_ADDRESS'
        if addrPort != nil
            addr, port = addrPort\match('^([^:]+):(%d+)')
            @stream = TcpStream.open(addr, tonumber(port))
        else
            @stream = ChildProcessStream.spawn {
                "/usr/bin/env", "nvim", "--embed", "--headless", "-n", "-u", "init.vim"
            }

        @session = Session.new @stream
        @session\request 'vim_eval', '1'  -- wait for nvim to start

    close: =>
        @session\close!
        @session = nil
        @stream\close!
        @stream = nil

    exe: (cmd, delay=100) =>
        @session\request 'vim_command', cmd
        luv.sleep delay

    getSigns: =>
        -- Get pointer position and list of breakpoints.
        out = @eval 'execute("sign place")'

        fname = nil     -- Filename where the current line sign is
        cur = nil       -- The return value from the function in the form fname:line
        for _, l in pairs({out\match (out\gsub("[^\n]*\n", "([^\n]*)\n"))})
            m = l\match 'Signs for ([^:]+):'
            if m != nil
                fname = m\gsub "(.*/)(.*)", "%2"
                continue
            m = l\match('    line=(%d+)%s+id=%d+%s+name=GdbCurrentLine')
            if m != nil
                -- There can be only one current line sign
                assert(cur == nil)
                cur = fname .. ":" .. m

        collectSigns = (name) ->
            signs = [tonumber(m) for m in out\gmatch('line=(%d+)%s+id=%d+%s+name=' .. name)]
            if #signs > 0
                table.sort(signs)
                signs
        {"cur": cur, "break": collectSigns('GdbBreakpoint'), "breakM": collectSigns('GdbDBreakpoint')}

    feed: (keys, delay=100) =>
        @session\request 'nvim_input', keys
        luv.sleep delay

    type: (keys, delay=100) =>
        @session\request 'nvim_feedkeys', keys
        luv.sleep delay

    eval: (expr) =>
        status, ret = @session\request 'nvim_eval', expr
        assert(status)
        ret

    countBuffers: =>
        @eval 'len(filter(range(bufnr("$") + 1), "buflisted(v:val)"))'

Engine!
