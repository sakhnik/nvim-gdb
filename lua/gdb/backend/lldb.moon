require "set_paths"
rex = require "rex_pcre"
BaseScm = require "gdb.scm"

r = rex.new                     -- construct a new matcher
m = (r, line) -> r\match(line)  -- matching function

--  lldb specifics

class LldbScm extends BaseScm
    new: (_, cursor, win) =>
        super!

        queryB = (...) -> win\queryBreakpoints!

        @addTrans(@paused, @running, r([[^Process \d+ resuming]]),      m, (...) -> cursor\hide!)
        @addTrans(@paused, @paused,  r([[ at [\032]{2}([^:]+):(\d+)]]), m, (f,l) -> win\jump(f,l))
        @addTrans(@paused, @paused,  r([[(lldb)]]),                     m, queryB)

        @addTrans(@running, @paused, r([[^Breakpoint \d+:]]),           m, queryB)
        @addTrans(@running, @paused, r([[^Process \d+ stopped]]),       m, queryB)
        @addTrans(@running, @paused, r([[(lldb)]]),                     m, queryB)

        @state = @running

backend =
    initScm: LldbScm
    delete_breakpoints: 'breakpoint delete'
    breakpoint: 'b'
    until: 'thread until'

backend
