#!/usr/bin/env python
"""Test generic operations of the plugin."""

import unittest
import engine
import config


eng = engine.Engine()

subtests = {}
if "gdb" in config.debuggers:
    subtests['gdb'] = {'launch': ' dd\n',
                       'tbreak_main': 'tbreak main\n'}
if "lldb" in config.debuggers:
    subtests['lldb'] = {'launch': ' dl\n',
                        'tbreak_main': 'breakpoint set -o true -n main\n'}


class TestGdb(unittest.TestCase):
    """Test class."""

    def test_10_quit(self):
        """=> Verify that the session exits correctly on window close."""
        cases = [["<esc>", ":GdbDebugStop<cr>"],
                 ["<esc>", "ZZ"],
                 ["<esc>", "<c-w>w", "ZZ"]]
        numBufs = eng.CountBuffers()
        # Use random backend, assuming all they behave the same way.
        backend = next(iter(subtests.keys()))
        for c in cases:
            with self.subTest(case=c):
                eng.KeyStrokeL(subtests[backend]["launch"], delay=1)
                for k in c:
                    eng.KeyStrokeL(k)
                self.assertEqual(1, eng.Eval('tabpagenr("$")'))
                # Check that no new buffers have left
                self.assertEqual(numBufs, eng.CountBuffers())

    def test_20_generic(self):
        """=> Test a generic use case."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                eng.KeyStroke(spec["launch"], delay=1)
                eng.KeyStroke(spec["tbreak_main"])
                eng.KeyStroke('run\n', delay=1)
                eng.KeyStrokeL('<esc>')

                cur, breaks = eng.GetSigns()
                self.assertEqual(17, cur)
                self.assertFalse(breaks)

                eng.KeyStrokeL('<f10>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(19, cur)
                self.assertFalse(breaks)

                eng.KeyStrokeL('<f11>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(10, cur)
                self.assertFalse(breaks)

                eng.KeyStrokeL('<f12>')
                cur, breaks = eng.GetSigns()
                self.assertIn(cur, [17, 19])  # different for different compilers
                self.assertFalse(breaks)

                eng.KeyStrokeL('<f5>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertFalse(breaks)

                eng.Command('GdbDebugStop')

    def test_30_breakpoint(self):
        """=> Test toggling breakpoints."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                eng.KeyStroke(spec["launch"], delay=1)
                eng.KeyStrokeL('<esc><c-w>k')
                eng.KeyStroke(":e src/test.cpp\n")
                eng.KeyStrokeL(':5<cr>')
                eng.KeyStrokeL('<f8>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertListEqual([5], breaks)

                eng.Command("GdbRun", delay=1)
                cur, breaks = eng.GetSigns()
                self.assertEqual(5, cur)
                self.assertListEqual([5], breaks)

                eng.KeyStrokeL('<f8>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(5, cur)
                self.assertFalse(breaks)

                eng.Command('GdbDebugStop')

    def test_35_breakpoint_cleanup(self):
        """=> Verify that breakpoints are cleaned up after session end."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                eng.KeyStroke(spec["launch"], delay=1)
                eng.KeyStrokeL('<esc><c-w>k')
                eng.KeyStroke(":e src/test.cpp\n")
                eng.KeyStrokeL(':5<cr>')
                eng.KeyStrokeL('<f8>')
                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertListEqual([5], breaks)

                eng.Command("GdbDebugStop")
                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertFalse(breaks)

    def test_40_multiview(self):
        """=> Test multiple views."""
        backends = list(subtests.keys())
        backend1 = backends[0]
        if len(backends) > 1:
            backend2 = backends[1]
        else:
            backend2 = backend1

        # Launch the first backend
        eng.KeyStroke(subtests[backend1]["launch"], delay=1)
        eng.KeyStroke(subtests[backend1]["tbreak_main"])
        eng.KeyStroke('run\n', delay=1)
        eng.KeyStrokeL('<esc>')
        eng.KeyStrokeL('<c-w>w')
        eng.KeyStrokeL(':11<cr>')
        eng.KeyStrokeL('<f8>')
        eng.KeyStrokeL('<f10>')
        eng.KeyStrokeL('<f11>')

        cur, breaks = eng.GetSigns()
        self.assertEqual(10, cur)
        self.assertEqual([11], breaks)

        # Then launch the second backend
        eng.KeyStroke(subtests[backend2]["launch"], delay=1)
        eng.KeyStroke(subtests[backend2]["tbreak_main"])
        eng.KeyStroke('run\n', delay=1)
        eng.KeyStrokeL('<esc>')
        eng.KeyStrokeL('<c-w>w')
        eng.KeyStrokeL(':5<cr>')
        eng.KeyStrokeL('<f8>')
        eng.KeyStrokeL(':12<cr>')
        eng.KeyStrokeL('<f8>')
        eng.KeyStrokeL('<f10>')

        cur, breaks = eng.GetSigns()
        self.assertEqual(19, cur)
        self.assertEqual([5, 12], breaks)

        # Switch to the first backend
        eng.KeyStrokeL('2gt')
        cur, breaks = eng.GetSigns()
        self.assertEqual(10, cur)
        self.assertEqual([11], breaks)

        # Quit
        eng.KeyStrokeL('ZZ')

        # Switch back to the second backend
        cur, breaks = eng.GetSigns()
        self.assertEqual(19, cur)
        self.assertEqual([5, 12], breaks)

        # Quit LLDB
        eng.KeyStrokeL('ZZ')

    def test_50_interrupt(self):
        """=> Test interrupt."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                eng.KeyStroke(spec["launch"], delay=1)
                eng.KeyStroke('run\n', delay=1)
                eng.KeyStrokeL('<esc>')
                eng.KeyStroke(':GdbInterrupt\n', delay=0.3)

                cur, breaks = eng.GetSigns()
                self.assertEqual(22, cur)
                self.assertFalse(breaks)

                eng.KeyStrokeL('ZZ')

    def test_60_until(self):
        """=> Test run until."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                eng.KeyStroke(spec["launch"], delay=1)
                eng.KeyStroke(spec["tbreak_main"])
                eng.KeyStroke('run\n', delay=1)
                eng.KeyStrokeL('<esc>')

                eng.KeyStrokeL('<c-w>w')
                eng.KeyStrokeL(':21<cr>')
                eng.KeyStrokeL('<f4>')

                cur, breaks = eng.GetSigns()
                self.assertEqual(21, cur)
                self.assertFalse(breaks)

                eng.KeyStroke('ZZ')

    def test_70_keymap(self):
        """=> Test custom programmable keymaps."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                eng.KeyStroke(spec["launch"], delay=1)
                eng.KeyStroke(spec["tbreak_main"])
                eng.KeyStroke('run\n', delay=1)

                self.assertEqual(0, eng.Eval('g:test_tkeymap'))
                eng.KeyStroke('~tkm')
                self.assertEqual(1, eng.Eval('g:test_tkeymap'))
                eng.KeyStrokeL('<esc>')
                self.assertEqual(0, eng.Eval('g:test_keymap'))
                eng.KeyStroke('~tn')
                self.assertEqual(1, eng.Eval('g:test_keymap'))
                eng.KeyStrokeL(':let g:test_tkeymap = 0 | let g:test_keymap = 0<cr>')
                eng.KeyStrokeL('<c-w>w')
                self.assertEqual(0, eng.Eval('g:test_keymap'))
                eng.KeyStroke('~tn')
                self.assertEqual(1, eng.Eval('g:test_keymap'))
                eng.KeyStrokeL(':let g:test_keymap = 0<cr>')

                eng.KeyStroke('ZZ')


if __name__ == "__main__":
    unittest.main()
