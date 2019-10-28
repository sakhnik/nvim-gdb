'''Manipulating the current line sign.'''

from gdb.common import Common


class Cursor(Common):
    '''The current line sign operations.'''

    def __init__(self, common: Common):
        super().__init__(common)
        self.buf = -1
        self.line = -1
        self.sign_id = -1

    def hide(self):
        '''Hide the current line sign.'''
        if self.sign_id != -1:
            self.vim.call('sign_unplace', 'NvimGdb',
                          {'id': self.sign_id, 'buffer': self.buf})
            self.sign_id = -1

    def show(self):
        '''Show the current line sign.'''
        # To avoid flicker when removing/adding the sign column(due to
        # the change in line width), we switch ids for the line sign
        # and only remove the old line sign after marking the new one.
        old_sign_id: int = self.sign_id
        self.sign_id = 4999 + (4998 - old_sign_id if old_sign_id != -1 else 0)
        if self.line != -1 and self.buf != -1:
            self.vim.call('sign_place', self.sign_id, 'NvimGdb',
                          'GdbCurrentLine', self.buf,
                          {'lnum': self.line, 'priority': 20})
        if old_sign_id != -1:
            self.vim.call('sign_unplace', 'NvimGdb',
                          {'id': old_sign_id, 'buffer': self.buf})

    def set(self, buf: int, line: int):
        '''Set the current line sign number.'''
        self.buf = buf
        self.line = int(line)
