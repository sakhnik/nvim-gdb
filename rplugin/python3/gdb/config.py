'''Calculate current configuration from the defaults, Vim variables
   overrides and overloads.'''

import copy
import re
from gdb.keymaps import Keymaps


def _filter_funcref(vim, def_conf, key, val):
    '''Turn a string into a funcref looking up a Vim function.'''
    # Lookup the key in the default config.
    def_val = def_conf[key]
    # Check whether the key should be a function.
    if not callable(def_val):
        return val
    # Finally, turn the value into a Vim function call.
    return lambda _: vim.call(val)

def get_config(vim, logger):
    '''Get actual configuration with overrides resolved.'''
    # Default configuration
    default_config = {
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
        'sign_breakpoint': ['●', '●²', '●³', '●⁴', '●⁵', '●⁶', '●⁷', '●⁸',
                            '●⁹', '●ⁿ'],
        'split_command': 'split',
        'set_scroll_off': 5
        }

    # Make a copy of the supplied configuration if defined
    config = {}
    if vim.call("exists", 'g:nvimgdb_config'):
        config = vim.vars['nvimgdb_config']
        for key, val in config.items():
            try:
                config[key] = _filter_funcref(vim, default_config, key, val)
            except Exception as e:
                logger.log('config', "Exception: {}".format(str(e)))
        # Make sure the essential keys are present even if not supplied.
        for must_have in ('sign_current_line', 'sign_breakpoint',
                          'split_command', 'set_scroll_off'):
            if must_have not in config:
                config[must_have] = default_config[must_have]

    if not config:
        config = copy.deepcopy(default_config)

    # Check for keymap configuration sanity
    key_to_func = {}

    def check_keymap_conflicts(key, func, verbose):
        if re.match('^key_.*', func):
            prev_func = key_to_func.get(key, None)
            if prev_func and prev_func != func:
                if verbose:
                    vim.command(f"echo 'Overriding conflicting keymap"
                                f" \"{key}\" for {func} (was {prev_func})'")
                del key_to_func[config[func]]
                config[prev_func] = None
            key_to_func[key] = func

    for func, key in config.items():
        check_keymap_conflicts(key, func, True)

    # If there is config override defined, add it
    if vim.call("exists", 'g:nvimgdb_config_override'):
        override = vim.vars['nvimgdb_config_override']
        if override:
            for key, val in override.items():
                key_val = _filter_funcref(vim, default_config, key, val)
                check_keymap_conflicts(key_val, key, True)
                config[key] = key_val

    # See whether a global override for a specific configuration
    # key exists. If so, update the config.
    for key, _ in default_config.items():
        vname = 'nvimgdb_' + key
        if vim.call("exists", 'g:'+vname):
            val = vim.vars[vname]
            if val:
                key_val = _filter_funcref(vim, default_config, key, val)
                check_keymap_conflicts(key_val, key, False)
                config[key] = key_val

    # Return the resulting configuration
    config = {key: val for key, val in config.items() if val}
    return config
