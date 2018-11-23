
fmt = string.format

class Keymaps
    default_keymaps: {
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
        for _, keymap in pairs(default_keymaps)
            key = @config[2]
            if key != nil
                V.exe fmt([[%snoremap <buffer> <silent> %s %s<cr>]], keymap[1], key, keymap[3])

    unset: =>
        for _, keymap in pairs(default_keymaps)
            key = @config[2]
            if key != nil
                V.exe fmt([[%sunmap <buffer> %s]], keymaps[1], key)

    default_tkeymaps: {
        {'key_until',    ':GdbUntil'}
        {'key_continue', ':GdbContinue'}
        {'key_next',     ':GdbNext'}
        {'key_step',     ':GdbStep'}
        {'key_finish',   ':GdbFinish'}
    }

    setT: =>
        -- Set term-local key maps
        for _, keymap in pairs(default_tkeymaps)
            key = @config[keymap[1]]
            if key != nil
                V.exe fmt([[tnoremap <buffer> <silent> %s <c-\><c-n>%s<cr>i]], key, keymap[2])
        V.exe [[tnoremap <silent> <buffer> <esc> <c-\><c-n>]]


    -- Default configuration
    default_config:
        'key_until': '<f4>'
        'key_continue': '<f5>'
        'key_next': '<f10>'
        'key_step': '<f11>'
        'key_finish': '<f12>'
        'key_breakpoint': '<f8>'
        'key_frameup': '<c-p>'
        'key_framedown': '<c-n>'
        'key_eval': '<f9>'
        'set_tkeymaps': setT
        'set_keymaps': set
        'unset_keymaps': unset


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

    new: =>
        -- Make a copy of the supplied configuration if defined
        config = V.get_var('nvimgdb_config')
        if config == nil
            config = {table.unpack(default_config)}

        -- If there is config override defined, add it
        override = V.get_var('nvimgdb_config_override')
        if override != nil
            for k,v in pairs(override)
                config[k] = v

        -- See whether a global override for a specific configuration
        -- key exists. If so, update the config.
        for key,_ in pairs(config)
            val = V.get_var('nvimgdb_' .. key)
            if val != nil
                config[key] = val

        -- Remember the resulting configuration
        @config = config
