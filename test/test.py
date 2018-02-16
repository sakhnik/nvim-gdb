#!/usr/bin/env python

import os
import time
import re
import unittest
from neovim import attach


# Neovim proxy
class Engine:

    def __init__(self):
        if not os.path.isfile('a.out'):
            os.system('g++ -g test.cpp')
        self.nvim = attach('child', argv=["/bin/env", "nvim", "--embed", "-n", "-u", "init.vim"])
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
        breaks = [int(l) for l in re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbBreakpoint', out)]
        return (curline[0] if curline else -1), breaks

    def KeyStrokeL(self, keys):
        self.nvim.input(keys)
        time.sleep(0.1)

    def KeyStroke(self, keys):
        self.nvim.feedkeys(keys, 't')
        time.sleep(0.1)


engine = Engine()
subtests = {"gdb": ['\\dd', '\n'], "lldb": ['\dl', '\n']}


class TestGdb(unittest.TestCase):

    def test_generic(self):
        for backend, launch in subtests.items():
            with self.subTest(backend=backend):
                for k in launch:
                    engine.KeyStroke(k)
                engine.KeyStroke('tbreak main\n')
                engine.KeyStroke('run\n')
                engine.KeyStrokeL('<esc>')

                cur, breaks = engine.GetSigns()
                self.assertEqual(16, cur)
                self.assertFalse(breaks)

                engine.KeyStrokeL('<f10>')
                cur, breaks = engine.GetSigns()
                self.assertEqual(18, cur)
                self.assertFalse(breaks)

                engine.KeyStrokeL('<f11>')
                cur, breaks = engine.GetSigns()
                self.assertEqual(9, cur)
                self.assertFalse(breaks)

                engine.KeyStrokeL('<f12>')
                cur, breaks = engine.GetSigns()
                self.assertEqual(16, cur)
                self.assertFalse(breaks)

                engine.KeyStrokeL('<f5>')
                cur, breaks = engine.GetSigns()
                self.assertEqual(-1, cur)
                self.assertFalse(breaks)

                engine.Command('GdbDebugStop')

    def test_breakpoint(self):
        for backend, launch in subtests.items():
            with self.subTest(backend=backend):
                for k in launch:
                    engine.KeyStroke(k)
                engine.KeyStrokeL('<esc><c-w>k')
                engine.KeyStroke(":e test.cpp\n")
                engine.KeyStrokeL(':4<cr>')
                time.sleep(1)
                engine.KeyStrokeL('<f8>')
                cur, breaks = engine.GetSigns()
                self.assertEqual(-1, cur)
                self.assertListEqual([4], breaks)

                engine.Command("GdbRun")
                time.sleep(0.2)
                cur, breaks = engine.GetSigns()
                self.assertEqual(4, cur)
                self.assertListEqual([4], breaks)

                engine.KeyStrokeL('<f8>')
                cur, breaks = engine.GetSigns()
                self.assertEqual(4, cur)
                self.assertFalse(breaks)

                engine.Command('GdbDebugStop')


if __name__ == "__main__":
    unittest.main()
