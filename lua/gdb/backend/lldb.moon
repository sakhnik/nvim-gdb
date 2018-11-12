rex = require "rex_pcre"

r = rex.new                     -- construct a new matcher
m = (r, line) -> r\match(line)  -- matching function

--  lldb specifics

InitScm = ->
    class LldbScm extends gdb.scm.BaseScm
        new: =>
            super!

            @addTrans(@paused, r([[^Process \d+ resuming]]),      m, @continue)
            @addTrans(@paused, r([[ at [\032]{2}([^:]+):(\d+)]]), m, @jump)
            @addTrans(@paused, r([[(lldb)]]),                     m, @query)

            @addTrans(@running, r([[^Breakpoint \d+:]]),          m, @pause)
            @addTrans(@running, r([[^Process \d+ stopped]]),      m, @pause)
            @addTrans(@running, r([[(lldb)]]),                    m, @pause)

            @state = @running

    LldbScm!

backend =
    initScm: InitScm
    delete_breakpoints: 'breakpoint delete'
    breakpoint: 'b'
    until: 'thread until'

backend
