require "set_paths"
rex = require "rex_pcre"
BaseScm = require "gdb.scm"

r = rex.new                     -- construct a new matcher

--  lldb specifics

class LldbScm extends BaseScm
    new: (cursor, win) =>
        super!

        check = (newState, action) ->
            (r, l) ->
                if nil != r\match l
                    action!
                    newState
        queryB = check @paused, win\queryBreakpoints

        @addTrans @paused, r([[^Process \d+ resuming]]),      check(@running, cursor\hide)
        @addTrans @paused, r([[ at [\032]{2}([^:]+):(\d+)]]), (r,l) ->
            f, l = r\match l
            if f != nil
                win\jump f, l
                @paused

        @addTrans @paused, r([[(lldb)]]),                 queryB
        @addTrans @running, r([[^Breakpoint \d+:]]),      queryB
        @addTrans @running, r([[^Process \d+ stopped]]),  queryB
        @addTrans @running, r([[(lldb)]]),                queryB

        @state = @running

backend =
    initScm: LldbScm
    delete_breakpoints: 'breakpoint delete'
    breakpoint: 'b'
    'until %s': 'thread until %s'

backend
