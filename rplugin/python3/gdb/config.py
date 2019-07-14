'''Calculate current configuration from the defaults, Vim variables
    overrides and overloads.'''

import copy
import re
from gdb.keymaps import Keymaps
from gdb.common import Common


class Config(Common):
    '''Resolved configuration.'''

    # Default configuration
    default = {
        'key_until': '<f4>',
        'key_continue': '<f5>',
        'key_next': '<f10>',
        'key_step': '<f11>',
        'key_finish': '<f12>',
        'key_breakpoint': '<f8>',
        'key_frameup': '<c-p>',
        'key_framedown': '<c-n>',
        'key_eval': '<f9>',
        'set_tkeymaps': Keymaps.set_t,
        'set_keymaps': Keymaps.set,
        'unset_keymaps': Keymaps.unset,
        'sign_current_line': '▶',
        'sign_breakpoint': ['●', '●²', '●³', '●⁴', '●⁵', '●⁶', '●⁷', '●⁸',
                            '●⁹', '●ⁿ'],
        'split_command': 'split',
        'set_scroll_off': 5
        }

    def __init__(self, common):
        '''Prepare actual configuration with overrides resolved.'''
        super().__init__(common)

        self.key_to_func = {}

        # Make a copy of the supplied configuration if defined
        self.config = self._copy_user_config()
        if not self.config:
            self.config = copy.deepcopy(Config.default)
        for func, key in self.config.items():
            self._check_keymap_conflicts(key, func, True)
        self._apply_overrides()
        # Remove undefined keys
        self.config = {key: val for key, val in self.config.items() if val}

        self._define_signs()

    def _filter_funcref(self, def_conf, key, val):
        '''Turn a string into a funcref looking up a Vim function.'''
        # Lookup the key in the default config.
        def_val = def_conf[key]
        # Check whether the key should be a function.
        if not callable(def_val):
            return val
        # Finally, turn the value into a Vim function call.
        return lambda _: self.vim.call(val)

    def _copy_user_config(self):
        # Make a copy of the supplied configuration if defined
        config = {}
        if self.vim.call("exists", 'g:nvimgdb_config'):
            config = self.vim.vars['nvimgdb_config']
            for key, val in config.items():
                # pylint: disable=broad-except
                try:
                    config[key] = self._filter_funcref(Config.default,
                                                       key, val)
                except Exception as ex:
                    self.log(f"Exception: {str(ex)}")
            # Make sure the essential keys are present even if not supplied.
            for must_have in ('sign_current_line', 'sign_breakpoint',
                              'split_command', 'set_scroll_off'):
                if must_have not in config:
                    config[must_have] = Config.default[must_have]
        return config

    def _apply_overrides(self):
        # If there is config override defined, add it
        if self.vim.call("exists", 'g:nvimgdb_config_override'):
            override = self.vim.vars['nvimgdb_config_override']
            if override:
                for key, val in override.items():
                    key_val = self._filter_funcref(Config.default, key, val)
                    self._check_keymap_conflicts(key_val, key, True)
                    self.config[key] = key_val

        # See whether a global override for a specific configuration
        # key exists. If so, update the config.
        for key, _ in Config.default.items():
            vname = 'nvimgdb_' + key
            if self.vim.call("exists", 'g:'+vname):
                val = self.vim.vars[vname]
                if val:
                    key_val = self._filter_funcref(Config.default, key, val)
                    self._check_keymap_conflicts(key_val, key, False)
                    self.config[key] = key_val

    def _check_keymap_conflicts(self, key, func, verbose):
        '''Check for keymap configuration sanity.'''
        if re.match('^key_.*', func):
            prev_func = self.key_to_func.get(key, None)
            if prev_func and prev_func != func:
                if verbose:
                    self.vim.command(
                        f"echo 'Overriding conflicting keymap"
                        f" \"{key}\" for {func} (was {prev_func})'")
                del self.key_to_func[self.config[func]]
                self.config[prev_func] = None
            self.key_to_func[key] = func

    def _define_signs(self):
        # Define the sign for current line the debugged program is executing.
        self.vim.command("sign define GdbCurrentLine text="
                         + self.config["sign_current_line"])
        # Define signs for the breakpoints.
        breaks = self.config["sign_breakpoint"]
        for i, brk in enumerate(breaks):
            self.vim.command(f'sign define GdbBreakpoint{i+1} text={brk}')

    def get(self, key):
        '''Get the configuration value by key.'''
        return self.config[key]

    def get_or(self, key, val):
        '''Get the configuration value by key or return the val if missing.'''
        return self.config.get(key, val)
