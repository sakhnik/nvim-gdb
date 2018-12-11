require "set_paths"
rex = require "rex_pcre"
BaseScm = require "gdb.scm"

r = rex.new                     -- construct a new matcher
m = (r, line) -> r\match(line)  -- matching function

-- gdb specifics

class GdbScm extends BaseScm
    new: (cursor, win) =>
        super!

        queryB = (...) -> win\queryBreakpoints!

        @addTrans(@paused, @running, r([[Continuing\.]]),               m, (...) -> cursor\hide!)
        @addTrans(@paused, @paused,  r([[[\032]{2}([^:]+):(\d+):\d+]]), m, (f,l) -> win\jump(f,l))
        @addTrans(@paused, @paused,  r([[^\(gdb\) ]]),                  m, queryB)

        @addTrans(@running, @paused, r([[^Breakpoint \d+]]),            m, queryB)
        @addTrans(@running, @paused, r([[ hit Breakpoint \d+]]),        m, queryB)
        @addTrans(@running, @paused, r([[^\(gdb\) ]]),                  m, queryB)

        @state = @running

backend =
    initScm: GdbScm
    delete_breakpoints: 'delete'
    breakpoint: 'break'

backend
