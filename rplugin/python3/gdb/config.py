from gdb.keymaps import Keymaps
import copy

# Calculate current configuration from the defaults, Vim variables overrides and overloads.

## Turn a string into a funcref either Lua or Vim, preferring Lua.
#filterFuncref = (defConf, k, v) ->
#    -- Lookup the key in the default config.
#    defVal = defConf[k]
#    if defVal == nil
#        return nil   -- No need to add it to the configuration.
#    -- Check whether the key should be a function.
#    if type(defVal) != 'function'
#        return v
#    -- NOTE: will be deprecated in Lua 5.2, so will have to use load() then.
#    func = loadstring(v)
#    if type(func) == 'function'
#        return func
#    -- Finally, turn the value into a Vim function call.
#    return -> V.call(v, {})

def getConfig():
    # Default configuration
    defaultConfig = {
        'key_until': '<f4>',
        'key_continue': '<f5>',
        'key_next': '<f10>',
        'key_step': '<f11>',
        'key_finish': '<f12>',
        'key_breakpoint': '<f8>',
        'key_frameup': '<c-p>',
        'key_framedown': '<c-n>',
        'key_eval': '<f9>',
        'set_tkeymaps': Keymaps.setT,
        'set_keymaps': Keymaps.set,
        'unset_keymaps': Keymaps.unset,
        'sign_current_line': '▶',
        'sign_breakpoint': [ '●', '●²', '●³', '●⁴', '●⁵', '●⁶', '●⁷', '●⁸', '●⁹', '●ⁿ' ],
        }

    # Make a copy of the supplied configuration if defined
    config = {}
    #if V.call("exists", {'g:nvimgdb_config'}) == 1
    #    config = V.get_var('nvimgdb_config')
    #    for k,v in pairs(config)
    #        config[k] = filterFuncref(defaultConfig, k, v)
    #    -- Make sure the essential keys are present even if not supplied.
    #    for _, mustHave in ipairs({'sign_current_line', 'sign_breakpoint'})
    #        if config[mustHave] == nil
    #            config[mustHave] = defaultConfig[mustHave]

    if not config:
        config = copy.deepcopy(defaultConfig)

    #-- Check for keymap configuration sanity
    #keyToFunc = {}
    #checkKeymapConflicts = (key, func, verbose) ->
    #    if func\match('^key_.*')
    #        prevFunc = keyToFunc[key]
    #        if prevFunc != nil and prevFunc != func
    #            if verbose
    #                print fmt("Overriding conflicting keymap '%s' for %s (was %s)", key, func, prevFunc)
    #            keyToFunc[config[func]] = nil
    #            config[prevFunc] = nil
    #        keyToFunc[key] = func

    #for func,key in pairs(config)
    #    checkKeymapConflicts key, func, true


    #-- If there is config override defined, add it
    #if V.call("exists", {'g:nvimgdb_config_override'}) != 0
    #    override = V.get_var('nvimgdb_config_override')
    #    if override != nil
    #        for k,v in pairs(override)
    #            keyVal = filterFuncref(defaultConfig, k, v)
    #            checkKeymapConflicts keyVal, k, true
    #            config[k] = keyVal

    #-- See whether a global override for a specific configuration
    #-- key exists. If so, update the config.
    #for key,_ in pairs(defaultConfig)
    #    vname = 'nvimgdb_' .. key
    #    if V.call("exists", {'g:'..vname}) != 0
    #        val = V.get_var(vname)
    #        if val != nil
    #            keyVal = filterFuncref(defaultConfig, key, val)
    #            checkKeymapConflicts keyVal, key, false
    #            config[key] = keyVal

    # Return the resulting configuration
    return config
