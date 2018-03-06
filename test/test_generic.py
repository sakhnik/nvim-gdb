#!/usr/bin/env python

import os
import time
import re
import unittest
from neovim import attach


delay = 0.5

# Neovim proxy
class Engine:

    def __init__(self):
        os.system('g++ -g src/test.cpp')
        addr = os.environ.get('NVIM_LISTEN_ADDRESS')
        if addr:
            self.nvim = attach('socket', path=addr)
        else:
            self.nvim = attach('child', argv=["/usr/bin/env", "nvim", "--embed", "-n", "-u", "init.vim"])

    def Command(self, cmd):
        self.nvim.command(cmd)
        time.sleep(delay)

    def GetSigns(self):
        out = self.nvim.eval('execute("sign place")')
        curline = [int(l) for l in re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbCurrentLine', out)]
        assert(len(curline) <= 1)
        breaks = [int(l) for l in re.findall(r'line=(\d+)\s+id=\d+\s+name=GdbBreakpoint', out)]
        return (curline[0] if curline else -1), breaks

    def KeyStrokeL(self, keys):
        self.nvim.input(keys)
        time.sleep(delay)

    def KeyStroke(self, keys):
        self.nvim.feedkeys(keys, 't')
        time.sleep(delay)

    def Eval(self, expr):
        return self.nvim.eval(expr)

    def CountBuffers(self):
        return sum(self.Eval('buflisted(%d)' % (i+1)) for i in range(0, self.Eval('bufnr("$")')))


engine = Engine()
subtests = {"gdb": [' dd', '\n'], "lldb": [' dl', '\n']}


class TestGdb(unittest.TestCase):

    def test_10_quit(self):
        ''' => Verify that the session exits correctly on window close '''
        cases = [["<esc>", ":GdbDebugStop<cr>"], ["<esc>","ZZ"], ["<esc>","<c-w>w","ZZ"]]
        numBufs = engine.CountBuffers()
        for c in cases:
            with self.subTest(case=c):
                for k in subtests['gdb']:
                    engine.KeyStrokeL(k)
                for k in c:
                    engine.KeyStrokeL(k)
                self.assertEqual(1, engine.Eval('tabpagenr("$")'))
                # Check that no new buffers have left
                self.assertEqual(numBufs, engine.CountBuffers())

    def test_20_generic(self):
        ''' => Test a generic use case '''
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

    def test_30_breakpoint(self):
        ''' => Test toggling breakpoints '''
        for backend, launch in subtests.items():
            with self.subTest(backend=backend):
                for k in launch:
                    engine.KeyStroke(k)
                engine.KeyStrokeL('<esc><c-w>k')
                engine.KeyStroke(":e src/test.cpp\n")
                engine.KeyStrokeL(':4<cr>')
                engine.KeyStrokeL('<f8>')
                cur, breaks = engine.GetSigns()
                self.assertEqual(-1, cur)
                self.assertListEqual([4], breaks)

                engine.Command("GdbRun")
                cur, breaks = engine.GetSigns()
                self.assertEqual(4, cur)
                self.assertListEqual([4], breaks)

                engine.KeyStrokeL('<f8>')
                cur, breaks = engine.GetSigns()
                self.assertEqual(4, cur)
                self.assertFalse(breaks)

                engine.Command('GdbDebugStop')

    def test_35_breakpoint_cleanup(self):
        ''' => Verify that breakpoints are cleaned up after session end'''
        launch = subtests['gdb']
        for k in launch:
            engine.KeyStroke(k)
        engine.KeyStrokeL('<esc><c-w>k')
        engine.KeyStroke(":e src/test.cpp\n")
        engine.KeyStrokeL(':4<cr>')
        engine.KeyStrokeL('<f8>')
        cur, breaks = engine.GetSigns()
        self.assertEqual(-1, cur)
        self.assertListEqual([4], breaks)

        engine.Command("GdbDebugStop")
        cur, breaks = engine.GetSigns()
        self.assertEqual(-1, cur)
        self.assertFalse(breaks)

    def test_40_multiview(self):
        ''' => Test multiple views '''
        # Launch GDB first
        for k in subtests['gdb']:
            engine.KeyStroke(k)
        engine.KeyStroke('tbreak main\n')
        engine.KeyStroke('run\n')
        engine.KeyStrokeL('<esc>')
        engine.KeyStrokeL('<c-w>w')
        engine.KeyStrokeL(':10<cr>')
        engine.KeyStrokeL('<f8>')
        engine.KeyStrokeL('<f10>')
        engine.KeyStrokeL('<f11>')

        cur, breaks = engine.GetSigns()
        self.assertEqual(9, cur)
        self.assertEqual([10], breaks)

        # Then launch LLDB
        for k in subtests['lldb']:
            engine.KeyStroke(k)
        engine.KeyStroke('tbreak main\n')
        engine.KeyStroke('run\n')
        engine.KeyStrokeL('<esc>')
        engine.KeyStrokeL('<c-w>w')
        engine.KeyStrokeL(':4<cr>')
        engine.KeyStrokeL('<f8>')
        engine.KeyStrokeL(':11<cr>')
        engine.KeyStrokeL('<f8>')
        engine.KeyStrokeL('<f10>')

        cur, breaks = engine.GetSigns()
        self.assertEqual(18, cur)
        self.assertEqual([4, 11], breaks)

        # Switch to GDB
        engine.KeyStrokeL('2gt')
        cur, breaks = engine.GetSigns()
        self.assertEqual(9, cur)
        self.assertEqual([10], breaks)

        # Quit GDB
        engine.KeyStrokeL('ZZ')

        # Switch back to LLDB
        cur, breaks = engine.GetSigns()
        self.assertEqual(18, cur)
        self.assertEqual([4, 11], breaks)

        # Quit LLDB
        engine.KeyStrokeL('ZZ')


if __name__ == "__main__":
    unittest.main()
