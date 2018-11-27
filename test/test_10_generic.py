#!/usr/bin/env python
"""Test generic operations of the plugin."""

import unittest
import engine
import config


e = engine.Engine()

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
        numBufs = e.CountBuffers()
        # Use random backend, assuming all they behave the same way.
        backend = next(iter(subtests.keys()))
        for c in cases:
            with self.subTest(case=c):
                e.In(subtests[backend]["launch"], delay=1)
                for k in c:
                    e.In(k)
                self.assertEqual(1, e.Eval('tabpagenr("$")'))
                # Check that no new buffers have left
                self.assertEqual(numBufs, e.CountBuffers())

    def test_20_generic(self):
        """=> Test a generic use case."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec["launch"], delay=1)
                e.Ty(spec["tbreak_main"])
                e.Ty('run\n', delay=1)
                e.In('<esc>')

                cur, breaks = e.GetSigns()
                self.assertEqual('test.cpp:17', cur)
                self.assertFalse(breaks)

                e.In('<f10>')
                cur, breaks = e.GetSigns()
                self.assertEqual('test.cpp:19', cur)
                self.assertFalse(breaks)

                e.In('<f11>')
                cur, breaks = e.GetSigns()
                self.assertEqual('test.cpp:10', cur)
                self.assertFalse(breaks)

                e.In('<f12>')
                cur, breaks = e.GetSigns()
                self.assertIn(cur, ['test.cpp:17', 'test.cpp:19'])  # different for different compilers
                self.assertFalse(breaks)

                e.In('<f5>')
                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertFalse(breaks)

                e.Exe('GdbDebugStop')

    def test_30_breakpoint(self):
        """=> Test toggling breakpoints."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec["launch"], delay=1)
                e.In('<esc><c-w>k')
                e.Ty(":e src/test.cpp\n")
                e.In(':5<cr>')
                e.In('<f8>')
                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertListEqual([5], breaks)

                e.Exe("GdbRun", delay=1)
                cur, breaks = e.GetSigns()
                self.assertEqual('test.cpp:5', cur)
                self.assertListEqual([5], breaks)

                e.In('<f8>')
                cur, breaks = e.GetSigns()
                self.assertEqual('test.cpp:5', cur)
                self.assertFalse(breaks)

                e.Exe('GdbDebugStop')

    def test_35_breakpoint_cleanup(self):
        """=> Verify that breakpoints are cleaned up after session end."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec["launch"], delay=1)
                e.In('<esc><c-w>k')
                e.Ty(":e src/test.cpp\n")
                e.In(':5<cr>')
                e.In('<f8>')
                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertListEqual([5], breaks)

                e.Exe("GdbDebugStop")
                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
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
        e.Ty(subtests[backend1]["launch"], delay=1)
        e.Ty(subtests[backend1]["tbreak_main"])
        e.Ty('run\n', delay=1)
        e.In('<esc>')
        e.In('<c-w>w')
        e.In(':11<cr>')
        e.In('<f8>')
        e.In('<f10>')
        e.In('<f11>')

        cur, breaks = e.GetSigns()
        self.assertEqual('test.cpp:10', cur)
        self.assertEqual([11], breaks)

        # Then launch the second backend
        e.Ty(subtests[backend2]["launch"], delay=1)
        e.Ty(subtests[backend2]["tbreak_main"])
        e.Ty('run\n', delay=1)
        e.In('<esc>')
        e.In('<c-w>w')
        e.In(':5<cr>')
        e.In('<f8>')
        e.In(':12<cr>')
        e.In('<f8>')
        e.In('<f10>')

        cur, breaks = e.GetSigns()
        self.assertEqual('test.cpp:19', cur)
        self.assertEqual([5, 12], breaks)

        # Switch to the first backend
        e.In('2gt')
        cur, breaks = e.GetSigns()
        self.assertEqual('test.cpp:10', cur)
        self.assertEqual([11], breaks)

        # Quit
        e.In('ZZ')

        # Switch back to the second backend
        cur, breaks = e.GetSigns()
        self.assertEqual('test.cpp:19', cur)
        self.assertEqual([5, 12], breaks)

        # Quit LLDB
        e.In('ZZ')

    def test_50_interrupt(self):
        """=> Test interrupt."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec["launch"], delay=1)
                e.Ty('run 4294967295\n', delay=1)
                e.In('<esc>')
                e.Ty(':GdbInterrupt\n', delay=0.3)

                cur, breaks = e.GetSigns()
                self.assertEqual('test.cpp:22', cur)
                self.assertFalse(breaks)

                e.In('ZZ')

    def test_60_until(self):
        """=> Test run until."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec["launch"], delay=1)
                e.Ty(spec["tbreak_main"])
                e.Ty('run\n', delay=1)
                e.In('<esc>')

                e.In('<c-w>w')
                e.In(':21<cr>')
                e.In('<f4>')

                cur, breaks = e.GetSigns()
                self.assertEqual('test.cpp:21', cur)
                self.assertFalse(breaks)

                e.Ty('ZZ')

    def test_70_keymap(self):
        """=> Test custom programmable keymaps."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec["launch"], delay=1)
                e.Ty(spec["tbreak_main"])
                e.Ty('run\n', delay=1)

                self.assertEqual(0, e.Eval('g:test_tkeymap'))
                e.Ty('~tkm')
                self.assertEqual(1, e.Eval('g:test_tkeymap'))
                e.In('<esc>')
                self.assertEqual(0, e.Eval('g:test_keymap'))
                e.Ty('~tn')
                self.assertEqual(1, e.Eval('g:test_keymap'))
                e.In(':let g:test_tkeymap = 0 | let g:test_keymap = 0<cr>')
                e.In('<c-w>w')
                self.assertEqual(0, e.Eval('g:test_keymap'))
                e.Ty('~tn')
                self.assertEqual(1, e.Eval('g:test_keymap'))
                e.In(':let g:test_keymap = 0<cr>')

                e.Ty('ZZ')

    def test_80_exit(self):
        """=> Test the cursor is hidden after program end."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec["launch"], delay=1)
                e.Ty(spec["tbreak_main"])
                e.Ty('run\n', delay=1)
                e.In('<esc>')

                e.In('<f5>')
                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertFalse(breaks)

                e.Ty('ZZ')


if __name__ == "__main__":
    unittest.main()
