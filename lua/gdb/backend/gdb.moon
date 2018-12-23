require "set_paths"
rex = require "rex_pcre"
BaseScm = require "gdb.scm"

r = rex.new                     -- construct a new matcher

-- gdb specifics

class GdbScm extends BaseScm
    new: (cursor, win) =>
        super!

        check = (newState, action) ->
            (r, l) ->
                if nil != r\match l
                    action!
                    newState
        queryB = check @paused, win\queryBreakpoints

        @addTrans @paused, r([[Continuing\.]]), check(@running, cursor\hide)
        @addTrans @paused, r([[[\032]{2}([^:]+):(\d+):\d+]]), (r,l) ->
            f, l = r\match l
            if f != nil
                win\jump f, l
                @paused

        @addTrans @paused, r([[^\(gdb\) ]]),             queryB
        @addTrans @running, r([[^Breakpoint \d+]]),      queryB
        @addTrans @running, r([[ hit Breakpoint \d+]]),  queryB
        @addTrans @running, r([[^\(gdb\) ]]),            queryB

        @state = @running

backend =
    initScm: GdbScm
    delete_breakpoints: 'delete'
    breakpoint: 'break'

backend
