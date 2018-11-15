require "set_paths"
rex = require "rex_pcre"

r = rex.new                     -- construct a new matcher
m = (r, line) -> r\match(line)  -- matching function

-- gdb specifics

class GdbScm extends gdb.scm.BaseScm
    new: (...) =>
        super select(2, ...)

        @addTrans(@paused, r([[Continuing\.]]),               m, @continue)
        @addTrans(@paused, r([[[\032]{2}([^:]+):(\d+):\d+]]), m, @jump)
        @addTrans(@paused, r([[^\(gdb\) ]]),                  m, @query)

        @addTrans(@running, r([[^Breakpoint \d+]]),           m, @pause)
        @addTrans(@running, r([[ hit Breakpoint \d+]]),       m, @pause)
        @addTrans(@running, r([[^\(gdb\) ]]),                 m, @pause)

        @state = @running

backend =
    initScm: GdbScm
    delete_breakpoints: 'delete'
    breakpoint: 'break'
    until: 'until'

backend
