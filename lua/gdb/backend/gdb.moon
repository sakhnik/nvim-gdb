BaseScm = require "gdb.scm"

-- gdb specifics

class GdbScm extends BaseScm
    new: (cursor, win) =>
        super!

        @addTrans @paused, nil, (_,l) ->
            if nil != l\match "^Continuing%."
                cursor\hide!
                @running

        @addTrans @paused, nil, (_,l) ->
            file, line = l\match "^\x1a\x1a([^:]+):(%d+):%d+"
            if file != nil
                win\jump file, line
                @paused

        queryB = (r,l) ->
            if nil != l\match r
                win\queryBreakpoints!
                @paused

        @addTrans @paused,  "^%(gdb%) ",            queryB
        @addTrans @running, "^Breakpoint %d+",      queryB
        @addTrans @running, " hit Breakpoint %d+",  queryB
        @addTrans @running, "^%(gdb%) ",            queryB

        @state = @running

backend =
    initScm: GdbScm
    delete_breakpoints: 'delete'
    breakpoint: 'break'

backend
