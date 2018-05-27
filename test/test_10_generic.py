#!/usr/bin/env python

import unittest
import engine


eng = engine.Engine()
subtests = {"gdb": [' dd', '\n'], "lldb": [' dl', '\n']}
tbreak_main = {"gdb": 'tbreak main\n', "lldb": 'breakpoint set -o true -n main\n'}


class TestGdb(unittest.TestCase):

    def test_10_quit(self):
        ''' => Verify that the session exits correctly on window close '''
        cases = [["<esc>", ":GdbDebugStop<cr>"], ["<esc>","ZZ"], ["<esc>","<c-w>w","ZZ"]]
        numBufs = eng.CountBuffers()
        for c in cases:
            with self.subTest(case=c):
                for k in subtests['gdb']:
                    eng.KeyStrokeL(k)
                for k in c:
                    eng.KeyStrokeL(k)
                self.assertEqual(1, eng.Eval('tabpagenr("$")'))
                # Check that no new buffers have left
                self.assertEqual(numBufs, eng.CountBuffers())

    def test_20_generic(self):
        ''' => Test a generic use case '''
        for backend, launch in subtests.items():
            with self.subTest(backend=backend):
                for k in launch:
                    eng.KeyStroke(k)
                eng.KeyStroke(tbreak_main[backend])
                eng.KeyStroke('run\n')
                eng.KeyStrokeL('<esc>')

                cur, breaks = eng.GetSigns()
                self.assertEqual(16, cur)
                self.assertFalse(breaks)

                eng.KeyStrokeL('<f10>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(18, cur)
                self.assertFalse(breaks)

                eng.KeyStrokeL('<f11>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(9, cur)
                self.assertFalse(breaks)

                eng.KeyStrokeL('<f12>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(16, cur)
                self.assertFalse(breaks)

                eng.KeyStrokeL('<f5>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertFalse(breaks)

                eng.Command('GdbDebugStop')

    def test_30_breakpoint(self):
        ''' => Test toggling breakpoints '''
        for backend, launch in subtests.items():
            with self.subTest(backend=backend):
                for k in launch:
                    eng.KeyStroke(k)
                eng.KeyStrokeL('<esc><c-w>k')
                eng.KeyStroke(":e src/test.cpp\n")
                eng.KeyStrokeL(':4<cr>')
                eng.KeyStrokeL('<f8>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertListEqual([4], breaks)

                eng.Command("GdbRun")
                cur, breaks = eng.GetSigns()
                self.assertEqual(4, cur)
                self.assertListEqual([4], breaks)

                eng.KeyStrokeL('<f8>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(4, cur)
                self.assertFalse(breaks)

                eng.Command('GdbDebugStop')

    def test_35_breakpoint_cleanup(self):
        ''' => Verify that breakpoints are cleaned up after session end'''
        launch = subtests['gdb']
        for k in launch:
            eng.KeyStroke(k)
        eng.KeyStrokeL('<esc><c-w>k')
        eng.KeyStroke(":e src/test.cpp\n")
        eng.KeyStrokeL(':4<cr>')
        eng.KeyStrokeL('<f8>')
        cur, breaks = eng.GetSigns()
        self.assertEqual(-1, cur)
        self.assertListEqual([4], breaks)

        eng.Command("GdbDebugStop")
        cur, breaks = eng.GetSigns()
        self.assertEqual(-1, cur)
        self.assertFalse(breaks)

    def test_40_multiview(self):
        ''' => Test multiple views '''
        # Launch GDB first
        for k in subtests['gdb']:
            eng.KeyStroke(k)
        eng.KeyStroke(tbreak_main['gdb'])
        eng.KeyStroke('run\n')
        eng.KeyStrokeL('<esc>')
        eng.KeyStrokeL('<c-w>w')
        eng.KeyStrokeL(':10<cr>')
        eng.KeyStrokeL('<f8>')
        eng.KeyStrokeL('<f10>')
        eng.KeyStrokeL('<f11>')

        cur, breaks = eng.GetSigns()
        self.assertEqual(9, cur)
        self.assertEqual([10], breaks)

        # Then launch LLDB
        for k in subtests['lldb']:
            eng.KeyStroke(k)
        eng.KeyStroke(tbreak_main['lldb'])
        eng.KeyStroke('run\n')
        eng.KeyStrokeL('<esc>')
        eng.KeyStrokeL('<c-w>w')
        eng.KeyStrokeL(':4<cr>')
        eng.KeyStrokeL('<f8>')
        eng.KeyStrokeL(':11<cr>')
        eng.KeyStrokeL('<f8>')
        eng.KeyStrokeL('<f10>')

        cur, breaks = eng.GetSigns()
        self.assertEqual(18, cur)
        self.assertEqual([4, 11], breaks)

        # Switch to GDB
        eng.KeyStrokeL('2gt')
        cur, breaks = eng.GetSigns()
        self.assertEqual(9, cur)
        self.assertEqual([10], breaks)

        # Quit GDB
        eng.KeyStrokeL('ZZ')

        # Switch back to LLDB
        cur, breaks = eng.GetSigns()
        self.assertEqual(18, cur)
        self.assertEqual([4, 11], breaks)

        # Quit LLDB
        eng.KeyStrokeL('ZZ')


    def test_50_interrupt(self):
        ''' => Test interrupt '''
        for backend, launch in subtests.items():
            with self.subTest(backend=backend):
                for k in launch:
                    eng.KeyStroke(k)
                eng.KeyStroke('run\n')
                eng.KeyStrokeL('<esc>')
                eng.KeyStroke(':GdbInterrupt\n')

                cur, breaks = eng.GetSigns()
                self.assertEqual(20, cur)
                self.assertFalse(breaks)

                eng.KeyStrokeL('ZZ')



if __name__ == "__main__":
    unittest.main()
