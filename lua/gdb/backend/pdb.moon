rex = require "rex_pcre"

r = rex.new                     -- construct a new matcher
m = (r, line) -> r\match(line)  -- matching function

-- pdb specifics

InitScm = ->
    class PdbScm extends gdb.scm.BaseScm
        new: =>
            super!
            @addTrans(@paused, r([[(?<!-)> ([^(]+)\((\d+)\)[^(]+\(\)]]), m, @jump)
            @addTrans(@paused, r([[^\(Pdb\) ]]),                         m, @query)
            @state = @paused
    PdbScm!

backend =
    initScm: InitScm
    delete_breakpoints: 'clear'
    breakpoint: 'break'
    finish: 'return'
    until: 'until'

backend
