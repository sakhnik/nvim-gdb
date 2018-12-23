require "set_paths"
rex = require "rex_pcre"
BaseScm = require "gdb.scm"

r = rex.new                     -- construct a new matcher

-- pdb specifics

class PdbScm extends BaseScm
    new: (cursor, win) =>
        super!
        check = (newState, action) ->
            (r, l) ->
                if nil != r\match l
                    action!
                    newState
        queryB = check @paused, win\queryBreakpoints
        @addTrans @paused, nil, (r,line) ->
            it = line\gmatch "> ([^(]+)%((%d+)%)[^(]+%(%)"
            file, line = it()
            if file != nil
                win\jump file, line
                @paused
        @addTrans @paused, r([[^\(Pdb\) ]]), queryB
        @state = @paused

backend =
    initScm: PdbScm
    delete_breakpoints: 'clear'
    breakpoint: 'break'
    finish: 'return'
    'print %s': 'print(%s)'

backend
