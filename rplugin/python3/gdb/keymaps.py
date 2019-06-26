class Keymaps:
    def __init__(self, vim, logger, config):
        self.vim = vim
        self.log = lambda msg: logger.log('keymaps', msg)
        self.config = config
        self.dispatchActive = True

    default = {
        ('n', 'key_until',      ':GdbUntil'),
        ('n', 'key_continue',   ':GdbContinue'),
        ('n', 'key_next',       ':GdbNext'),
        ('n', 'key_step',       ':GdbStep'),
        ('n', 'key_finish',     ':GdbFinish'),
        ('n', 'key_breakpoint', ':GdbBreakpointToggle'),
        ('n', 'key_frameup',    ':GdbFrameUp'),
        ('n', 'key_framedown',  ':GdbFrameDown'),
        ('n', 'key_eval',       ':GdbEvalWord'),
        ('v', 'key_eval',       ':GdbEvalRange'),
    }

    def set(self):
        for mode, key, cmd in Keymaps.default:
            try:
                keystroke = self.config[key]
                self.vim.command('%snoremap <buffer> <silent> %s %s<cr>' % (mode, keystroke, cmd))
            except Exception as e:
                self.log('Exception: {}'.format(str(e)))

    def unset(self):
        for mode, key, _ in Keymaps.default:
            try:
                keystroke = self.config[key]
                self.vim.command('%sunmap <buffer> %s' % (mode, keystroke))
            except Exception as e:
                self.log('Exception: {}'.format(str(e)))

    defaultT = {
        ('key_until',    ':GdbUntil'),
        ('key_continue', ':GdbContinue'),
        ('key_next',     ':GdbNext'),
        ('key_step',     ':GdbStep'),
        ('key_finish',   ':GdbFinish'),
    }

    def setT(self):
        # Set term-local key maps
        for key, cmd in Keymaps.defaultT:
            try:
                keystroke = self.config[key]
                self.vim.command('tnoremap <buffer> <silent> %s <c-\><c-n>%s<cr>i' % (keystroke, cmd))
            except Exception as e:
                self.log('Exception: {}'.format(str(e)))
        self.vim.command('tnoremap <silent> <buffer> <esc> <c-\><c-n>')


    def _dispatch(self, key):
        try:
            if self.dispatchActive:
                self.config[key](self)
        except Exception as e:
            self.log('Exception: {}'.format(str(e)))

    def dispatchSet(self):
        self._dispatch('set_keymaps')

    def dispatchUnset(self):
        self._dispatch('unset_keymaps')

    def dispatchSetT(self):
        self._dispatch('set_tkeymaps')

    def setDispatchActive(self, state):
        self.dispatchActive = state
