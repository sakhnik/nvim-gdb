from gdb.keymaps import Keymaps
import copy
import re

# Calculate current configuration from the defaults, Vim variables overrides and overloads.

# Turn a string into a funcref looking up a Vim function.
def filterFuncref(vim, defConf, k, v):
    # Lookup the key in the default config.
    defVal = defConf[k]
    # Check whether the key should be a function.
    if not callable(defVal):
        return v
    # Finally, turn the value into a Vim function call.
    return lambda _: vim.call(v)

def getConfig(vim):
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
        'split_command': 'split',
        }

    # Make a copy of the supplied configuration if defined
    config = {}
    if vim.call("exists", 'g:nvimgdb_config'):
        config = vim.vars['nvimgdb_config']
        for k,v in config.items():
            try:
                config[k] = filterFuncref(vim, defaultConfig, k, v)
            except:
                pass
        # Make sure the essential keys are present even if not supplied.
        for mustHave in ('sign_current_line', 'sign_breakpoint', 'split_command'):
            if not mustHave in config:
                config[mustHave] = defaultConfig[mustHave]

    if not config:
        config = copy.deepcopy(defaultConfig)

    # Check for keymap configuration sanity
    keyToFunc = {}
    def checkKeymapConflicts(key, func, verbose):
        if re.match('^key_.*', func):
            prevFunc = keyToFunc.get(key, None)
            if prevFunc and prevFunc != func:
                if verbose:
                    vim.command("echo 'Overriding conflicting keymap \"{}\" for {} (was {})'" \
                            .format(key, func, prevFunc))
                del(keyToFunc[config[func]])
                config[prevFunc] = None
            keyToFunc[key] = func

    for func,key in config.items():
        checkKeymapConflicts(key, func, True)


    # If there is config override defined, add it
    if vim.call("exists", 'g:nvimgdb_config_override'):
        override = vim.vars['nvimgdb_config_override']
        if override:
            for k,v in override.items():
                keyVal = filterFuncref(vim, defaultConfig, k, v)
                checkKeymapConflicts(keyVal, k, True)
                config[k] = keyVal

    # See whether a global override for a specific configuration
    # key exists. If so, update the config.
    for key in defaultConfig.keys():
        vname = 'nvimgdb_' + key
        if vim.call("exists", 'g:'+vname):
            val = vim.vars[vname]
            if val:
                keyVal = filterFuncref(vim, defaultConfig, key, val)
                checkKeymapConflicts(keyVal, key, False)
                config[key] = keyVal

    # Return the resulting configuration
    config = {k:v for k,v in config.items() if v}
    return config
