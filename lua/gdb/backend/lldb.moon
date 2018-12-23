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
        @addTrans @paused, nil, (_,l) ->
            file, line = l\match " at \x1a\x1a([^:]+):(%d+)"
            if file != nil
                win\jump file, line
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
