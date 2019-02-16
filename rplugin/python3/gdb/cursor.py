class Cursor:
    def __init__(self, vim):
        self.vim = vim
        self.buf = -1
        self.line = -1
        self.sign_id = -1

    def hide(self):
        if self.sign_id != -1:
            self.vim.command('sign unplace %d' % self.sign_id)
            self.sign_id = -1

    def show(self):
        # To avoid flicker when removing/adding the sign column(due to the change in
        # line width), we switch ids for the line sign and only remove the old line
        # sign after marking the new one
        old_sign_id = self.sign_id
        self.sign_id = 4999 + (4998 - old_sign_id if old_sign_id != -1 else 0)
        if self.line != -1 and self.buf != -1:
            self.vim.command('sign place %d name=GdbCurrentLine line=%d buffer=%d'
                % (self.sign_id, self.line, self.buf))
        if old_sign_id != -1:
            self.vim.command('sign unplace %d' % old_sign_id)

    def set(self, buf, line):
        self.buf = buf
        self.line = int(line)

    # Redraw the cursor sign if it was visible before.
    def reshow(self):
        if self.sign_id != -1:
            self.show()
