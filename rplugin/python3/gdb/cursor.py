'''Manipulating the current line sign.'''

from gdb.common import Common


class Cursor(Common):
    '''The current line sign operations.'''
    def __init__(self, common):
        super().__init__(common)
        self.buf = -1
        self.line = -1
        self.sign_id = -1

    def hide(self):
        '''Hide the current line sign.'''
        if self.sign_id != -1:
            self.vim.command(f'sign unplace {self.sign_id}')
            self.sign_id = -1

    def show(self):
        '''Show the current line sign.'''
        # To avoid flicker when removing/adding the sign column(due to
        # the change in line width), we switch ids for the line sign
        # and only remove the old line sign after marking the new one.
        old_sign_id = self.sign_id
        self.sign_id = 4999 + (4998 - old_sign_id if old_sign_id != -1 else 0)
        if self.line != -1 and self.buf != -1:
            self.vim.command(f'sign place {self.sign_id} name=GdbCurrentLine'
                             f' line={self.line} buffer={self.buf}')
        if old_sign_id != -1:
            self.vim.command(f'sign unplace {old_sign_id}')

    def set(self, buf, line):
        '''Set the current line sign number.'''
        self.buf = buf
        self.line = int(line)

    def reshow(self):
        '''Redraw the cursor sign if it was visible before.'''
        if self.sign_id != -1:
            self.show()
