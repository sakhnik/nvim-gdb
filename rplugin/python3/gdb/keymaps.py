V = require "gdb.v"

fmt = string.format

class Keymaps
    new: (config) =>
        @config = config

    defaultKeymaps: {
        {'n', 'key_until',      ':GdbUntil'}
        {'n', 'key_continue',   ':GdbContinue'}
        {'n', 'key_next',       ':GdbNext'}
        {'n', 'key_step',       ':GdbStep'}
        {'n', 'key_finish',     ':GdbFinish'}
        {'n', 'key_breakpoint', ':GdbBreakpointToggle'}
        {'n', 'key_frameup',    ':GdbFrameUp'}
        {'n', 'key_framedown',  ':GdbFrameDown'}
        {'n', 'key_eval',       ':GdbEvalWord'}
        {'v', 'key_eval',       ':GdbEvalRange'}
    }

    set: =>
        for _, keymap in pairs(@defaultKeymaps)
            key = @config[keymap[2]]
            if key != nil
                c = fmt([[%snoremap <buffer> <silent> %s %s<cr>]], keymap[1], key, keymap[3])
                V.exe c

    unset: =>
        for _, keymap in pairs(@defaultKeymaps)
            key = @config[keymap[2]]
            if key != nil
                c = fmt([[%sunmap <buffer> %s]], keymap[1], key)
                V.exe c

    setT: =>
        -- Set term-local key maps
        defaultTkeymaps = {
            {'key_until',    ':GdbUntil'}
            {'key_continue', ':GdbContinue'}
            {'key_next',     ':GdbNext'}
            {'key_step',     ':GdbStep'}
            {'key_finish',   ':GdbFinish'}
        }

        for _, keymap in pairs(defaultTkeymaps)
            key = @config[keymap[1]]
            if key != nil
                V.exe fmt([[tnoremap <buffer> <silent> %s <c-\><c-n>%s<cr>i]], key, keymap[2])
        V.exe [[tnoremap <silent> <buffer> <esc> <c-\><c-n>]]


    dispatch: (key) =>
        cfg = @config[key]
        if cfg != nil
            cfg(@)

    dispatchSet: =>
        @dispatch 'set_keymaps'

    dispatchUnset: =>
        @dispatch 'unset_keymaps'

    dispatchSetT: =>
        @dispatch 'set_tkeymaps'

Keymaps
