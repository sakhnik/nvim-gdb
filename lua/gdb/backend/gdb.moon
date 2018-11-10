rex = require "rex_pcre"

-- gdb specifics

InitScm = ->
    class GdbScm extends gdb.scm.Scm
        new: =>
            super!

            @addTrans(@paused, rex.new([[Continuing\.]]), @continue)
            @addTrans(@paused, rex.new([[[\032]{2}([^:]+):(\d+):\d+]]), @jump)
            @addTrans(@paused, rex.new([[^\(gdb\) ]]), @query)

            @addTrans(@running, rex.new([[^Breakpoint \d+]]), @pause)
            @addTrans(@running, rex.new([[ hit Breakpoint \d+]]), @pause)
            @addTrans(@running, rex.new([[^\(gdb\) ]]), @pause)

            @state = @running

    GdbScm!

backend =
    initScm: InitScm
    delete_breakpoints: 'delete'
    breakpoint: 'break'
    until: 'until'

backend
