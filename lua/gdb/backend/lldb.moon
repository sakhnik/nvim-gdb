BaseScm = require "gdb.scm"

--  lldb specifics

class LldbScm extends BaseScm
    new: (cursor, win) =>
        super!

        @addTrans @paused, nil, (_,l) ->
            if nil != l\match "^Process %d+ resuming"
                cursor\hide!
                @running

        @addTrans @paused, nil, (_,l) ->
            file, line = l\match " at \x1a\x1a([^:]+):(%d+)"
            if file != nil
                win\jump file, line
                @paused

        queryB = (r,l) ->
            if nil != l\match r
                win\queryBreakpoints!
                @paused

        @addTrans @paused,  "%(lldb%) ",             queryB
        @addTrans @running, "^Breakpoint %d+:",      queryB
        @addTrans @running, "^Process %d+ stopped",  queryB
        @addTrans @running, "%(lldb%) ",             queryB

        @state = @running

backend =
    initScm: LldbScm
    delete_breakpoints: 'breakpoint delete'
    breakpoint: 'b'
    'until %s': 'thread until %s'

backend
