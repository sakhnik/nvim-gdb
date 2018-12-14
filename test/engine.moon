--import os
--import time
--import re
--from neovim import attach
Session = require "nvim.session"
ChildProcessStream = require "nvim.child_process_stream"
luv = require "luv"


-- Neovim proxy
class Engine

    new: =>
        --addr = os.environ.get('NVIM_LISTEN_ADDRESS')
        --if addr:
        --    self.nvim = attach('socket', path=addr)
        --else:
        stream = ChildProcessStream.spawn {
            "/usr/bin/env", "nvim", "--embed", "--headless", "-n", "-u", "init.vim"
        }

        @session = Session.new stream
        @session\request 'vim_eval', '1'  -- wait for nvim to start

    exe: (cmd, delay=100) =>
        @session\request 'vim_command', cmd
        luv.sleep delay

    --def GetSigns(self):
    --    """Get pointer position and list of breakpoints."""

    --    out = self.nvim.eval('execute("sign place")')

    --    fname = ''     # Filename where the current line sign is
    --    curline = -1   # The line where the current line sign is
    --    cur = ''       # The return value from the function in the form fname:line
    --    for l in out.splitlines():
    --        m = re.match(r'Signs for ([^:]+):', l)
    --        if m:
    --            fname = os.path.basename(m.group(1))
    --            continue
    --        m = re.match(r'    line=(\d+)\s+id=\d+\s+name=GdbCurrentLine', l)
    --        if m:
    --            # There can be only one current line sign
    --            assert(curline == -1)
    --            curline = int(m.group(1))
    --            cur = "%s:%d" % (fname, curline)

    --    breaks = [int(l) for l
    --              in re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbBreakpoint',
    --                            out)]
    --    return cur, sorted(breaks)

    in: (keys, delay=100) =>
        @session\request 'nvim_input', keys
        luv.sleep delay

    ty: (keys, delay=100) =>
        @session\request 'nvim_feedkeys', keys
        luv.sleep delay

    eval: (expr) =>
        @session\request 'nvim_eval', expr

    countBuffers: =>
        bufs = @session\request 'nvim_list_bufs'
        print(bufs)

Engine
