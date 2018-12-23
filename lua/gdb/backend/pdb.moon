require "set_paths"
BaseScm = require "gdb.scm"

-- pdb specifics

class PdbScm extends BaseScm
    new: (cursor, win) =>
        super!
        @addTrans @paused, nil, (_,line) ->
            file, line = line\match "^> ([^(]+)%((%d+)%)[^(]+%(%)"
            if file != nil
                win\jump file, line
                @paused
        @addTrans @paused, nil, (_,line) ->
            if nil != line\match "^%(Pdb%) $"
                win\queryBreakpoints!
                @paused
        @state = @paused

backend =
    initScm: PdbScm
    delete_breakpoints: 'clear'
    breakpoint: 'break'
    finish: 'return'
    'print %s': 'print(%s)'

backend
