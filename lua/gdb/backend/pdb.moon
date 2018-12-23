require "set_paths"
BaseScm = require "gdb.scm"

-- pdb specifics

class PdbScm extends BaseScm
    new: (cursor, win) =>
        super!
        @addTrans @paused, nil, (_,line) ->
            for file, line in line\gmatch "> ([^(]+)%((%d+)%)[^(]+%(%)"
                win\jump file, line
                return @paused
        @addTrans @paused, nil, (_,line) ->
            for _ in line\gmatch "%(Pdb%) $"
                win\queryBreakpoints!
                return @paused
        @state = @paused

backend =
    initScm: PdbScm
    delete_breakpoints: 'clear'
    breakpoint: 'break'
    finish: 'return'
    'print %s': 'print(%s)'

backend
