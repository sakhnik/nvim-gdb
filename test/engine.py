import os
import time
import re
from neovim import attach

# Neovim proxy
class Engine:

    delay = 0.5

    def __init__(self):
        addr = os.environ.get('NVIM_LISTEN_ADDRESS')
        if addr:
            self.nvim = attach('socket', path=addr)
        else:
            self.nvim = attach('child', argv=["/usr/bin/env", "nvim", "--embed", "-n", "-u", "init.vim"])

    def Command(self, cmd):
        self.nvim.command(cmd)
        time.sleep(Engine.delay)

    def GetSigns(self):
        out = self.nvim.eval('execute("sign place")')
        curline = [int(l) for l in re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbCurrentLine', out)]
        assert(len(curline) <= 1)
        breaks = [int(l) for l in re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbBreakpoint', out)]
        return (curline[0] if curline else -1), breaks

    def KeyStrokeL(self, keys):
        self.nvim.input(keys)
        time.sleep(Engine.delay)

    def KeyStroke(self, keys):
        self.nvim.feedkeys(keys, 't')
        time.sleep(Engine.delay)

    def Eval(self, expr):
        return self.nvim.eval(expr)

    def CountBuffers(self):
        return sum(self.Eval('buflisted(%d)' % (i+1)) for i in range(0, self.Eval('bufnr("$")')))

