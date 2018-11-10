rex = require "rex_pcre"

-- pdb specifics

InitScm = ->
    class PdbScm extends gdb.scm.Scm
        new: =>
            super!
            @addTrans(@paused, rex.new([[(?<!-)> ([^(]+)\((\d+)\)[^(]+\(\)]]), @jump)
            @addTrans(@paused, rex.new([[^\(Pdb\) ]]), @query)
            @state = @paused
    PdbScm!

backend =
    initScm: InitScm
    delete_breakpoints: 'clear'
    breakpoint: 'break'
    finish: 'return'
    until: 'until'

backend
