'''Manipulate keymaps: define and undefined when needed.'''

# pylint: disable=broad-except

from gdb.common import Common


class Keymaps(Common):
    '''Keymaps manager.'''
    def __init__(self, common):
        super().__init__(common)
        self.dispatch_active = True

    def set_dispatch_active(self, state):
        '''Turn on/off keymaps manipulation.'''
        self.dispatch_active = state

    default = {
        ('n', 'key_until', ':GdbUntil'),
        ('n', 'key_continue', ':GdbContinue'),
        ('n', 'key_next', ':GdbNext'),
        ('n', 'key_step', ':GdbStep'),
        ('n', 'key_finish', ':GdbFinish'),
        ('n', 'key_breakpoint', ':GdbBreakpointToggle'),
        ('n', 'key_frameup', ':GdbFrameUp'),
        ('n', 'key_framedown', ':GdbFrameDown'),
        ('n', 'key_eval', ':GdbEvalWord'),
        ('v', 'key_eval', ':GdbEvalRange'),
    }

    def set(self):
        '''Set buffer-local keymaps.'''
        for mode, key, cmd in Keymaps.default:
            try:
                keystroke = self.config.get(key)
                self.vim.command(
                    f'{mode}noremap <buffer> <silent> {keystroke} {cmd}<cr>')
            except Exception:
                self.logger.exception('Exception')

    def unset(self):
        '''Unset buffer-local keymaps.'''
        for mode, key, _ in Keymaps.default:
            try:
                keystroke = self.config.get(key)
                self.vim.command(f'{mode}unmap <buffer> {keystroke}')
            except Exception:
                self.logger.exception('Exception')

    default_t = {
        ('key_until', ':GdbUntil'),
        ('key_continue', ':GdbContinue'),
        ('key_next', ':GdbNext'),
        ('key_step', ':GdbStep'),
        ('key_finish', ':GdbFinish'),
    }

    def set_t(self):
        '''Set term-local keymaps.'''
        for key, cmd in Keymaps.default_t:
            try:
                keystroke = self.config.get(key)
                self.vim.command(f'tnoremap <buffer> <silent> {keystroke}'
                                 rf' <c-\><c-n>{cmd}<cr>i')
            except Exception:
                self.logger.exception('Exception')
        self.vim.command(r'tnoremap <silent> <buffer> <esc> <c-\><c-n>G')

    def _dispatch(self, key):
        try:
            if self.dispatch_active:
                self.config.get(key)(self)
        except Exception:
            self.logger.exception('Exception')

    def dispatch_set(self):
        '''Call the hook to set the keymaps.'''
        self._dispatch('set_keymaps')

    def dispatch_unset(self):
        '''Call the hook to unset the keymaps.'''
        self._dispatch('unset_keymaps')

    def dispatch_set_t(self):
        '''Call the hook to set the terminal keymaps.'''
        self._dispatch('set_tkeymaps')
