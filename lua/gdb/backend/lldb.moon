rex = require "rex_pcre"

--  lldb specifics

InitScm = ->
    class LldbScm extends gdb.scm.Scm
        new: =>
            super!

            @addTrans(@paused, rex.new([[^Process \d+ resuming]]), @continue)
            @addTrans(@paused, rex.new([[ at [\032]{2}([^:]+):(\d+)]]), @jump)
            @addTrans(@paused, rex.new([[(lldb)]]), @query)

            @addTrans(@running, rex.new([[^Breakpoint \d+:]]), @pause)
            @addTrans(@running, rex.new([[^Process \d+ stopped]]), @pause)
            @addTrans(@running, rex.new([[(lldb)]]), @pause)

            @state = @running

    LldbScm!

backend =
    initScm: InitScm
    delete_breakpoints: 'breakpoint delete'
    breakpoint: 'b'
    until: 'thread until'

backend
