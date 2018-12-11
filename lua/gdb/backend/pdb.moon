require "set_paths"
rex = require "rex_pcre"
BaseScm = require "gdb.scm"

r = rex.new                     -- construct a new matcher
m = (r, line) -> r\match(line)  -- matching function

-- pdb specifics

class PdbScm extends BaseScm
    new: (cursor, win) =>
        super!
        queryB = (...) -> win\queryBreakpoints!
        @addTrans(@paused, @paused, r([[(?<!-)> ([^(]+)\((\d+)\)[^(]+\(\)]]), m, (f,l) -> win\jump(f,l))
        @addTrans(@paused, @paused, r([[^\(Pdb\) ]]),                         m, queryB)
        @state = @paused

backend =
    initScm: PdbScm
    delete_breakpoints: 'clear'
    breakpoint: 'break'
    finish: 'return'
    'print %s': 'print(%s)'

backend
