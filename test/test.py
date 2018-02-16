#!/usr/bin/env python

import os
import time
import re
import unittest
from neovim import attach

class Engine:
    def __init__(self):
        if not os.path.isfile('a.out'):
            os.system('g++ -g test.cpp')
        self.nvim = attach('child', argv=["/bin/env", "nvim", "--embed", "-u", "init.vim"])
        #self.nvim = attach('socket', path='/tmp/nvimtest')

    def Command(self, cmd):
        self.nvim.command(cmd)

    def GetSigns(self):
        self.nvim.command('redir @z')
        self.nvim.command('sign place')
        self.nvim.command('redir END')
        out = self.nvim.eval('getreg("z")')
        curline = [int(l) for l in re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbCurrentLine', out)]
        assert(len(curline) <= 1)
        # breaks = [int(l) for l in re.findall(r'line=(\d+)\s\+id=\d+name=')]
        return curline[0] if curline else -1

    def KeyStrokeL(self, keys):
        self.nvim.input(keys)
        time.sleep(0.1)

    def KeyStroke(self, keys):
        self.nvim.feedkeys(keys, 't')
        time.sleep(0.1)

class TestGdb(unittest.TestCase):
    def test_generic(self):
        engine = Engine()
        for backend, launch in {"gdb": ['\\dd', '\n'], "lldb": ['\dl', '\n']}.items():
            with self.subTest(backend=backend):
                for k in launch:
                    engine.KeyStroke(k)
                engine.KeyStroke('tbreak main\n')
                engine.KeyStroke('run\n')
                engine.KeyStrokeL('<esc>')
                cur = engine.GetSigns()
                self.assertEqual(16, cur)
                engine.KeyStrokeL('<f10>')
                cur = engine.GetSigns()
                self.assertEqual(18, cur)
                engine.KeyStrokeL('<f11>')
                cur = engine.GetSigns()
                self.assertEqual(9, cur)
                engine.KeyStrokeL('<f12>')
                cur = engine.GetSigns()
                self.assertEqual(16, cur)
                engine.KeyStrokeL('<f5>')
                cur = engine.GetSigns()
                self.assertEqual(-1, cur)
                engine.Command('GdbDebugStop')


if __name__ == "__main__":
    unittest.main()
