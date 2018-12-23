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

        @addTrans @paused, r([[Continuing\.]]), check(@running, cursor\hide)
        @addTrans @paused, nil, (_,l) ->
            file, line = l\match "^\x1a\x1a([^:]+):(%d+):%d+"
            if file != nil
                win\jump file, line
                return @paused

        queryB = (r,l) ->
            if nil != l\match r
                win\queryBreakpoints!
                return @paused

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
