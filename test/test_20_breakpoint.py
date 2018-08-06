#!/usr/bin/env python
"""Test breakpoint manipulation."""

import os
import unittest
import engine
import config


eng = engine.Engine()

subtests = {}
if "gdb" in config.debuggers:
    subtests['gdb'] = {'launch': [' dd', '\n'],
                       'break_main': 'break main\n'}
if "lldb" in config.debuggers:
    subtests['lldb'] = {'launch': [' dl', '\n'],
                        'break_main': 'breakpoint set --fullname main\n'}


class TestBreakpoint(unittest.TestCase):
    """Test class."""

    def test_10_detect(self):
        """=> Verify manual breakpoint is detected."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                for k in spec["launch"]:
                    eng.KeyStroke(k)
                eng.KeyStroke(spec["break_main"])
                eng.KeyStroke('run\n')

                cur, breaks = eng.GetSigns()
                self.assertEqual(17, cur)
                self.assertEqual([17], breaks)

                eng.KeyStrokeL('<esc>')
                eng.KeyStrokeL('ZZ')

    def test_20_cd(self):
        """=> Verify manual breakpoint is detected from a random directory."""
        exe_path = os.path.abspath('a.out')
        old_cwd = os.getcwd()

        subs = {'gdb': ":GdbStart gdb -q %s\n" % exe_path,
                'lldb': ":GdbStartLLDB lldb %s\n" % exe_path}

        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                try:
                    eng.KeyStroke(':cd /tmp\n')
                    eng.KeyStroke(subs[backend])
                    eng.KeyStroke(subtests[backend]["break_main"])
                    eng.KeyStroke('run\n')

                    cur, breaks = eng.GetSigns()
                    self.assertEqual(17, cur)
                    self.assertEqual([17], breaks)

                    eng.KeyStrokeL('<esc>')
                    eng.KeyStrokeL('ZZ')
                finally:
                    eng.KeyStroke(':cd %s\n' % old_cwd)

    def test_30_navigate(self):
        """=> Verify that breakpoints stay when source code is navigated."""
        break_bar = {"gdb": "break Bar\n", "lldb": "breakpoint set --fullname Bar\n"}
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                for k in spec['launch']:
                    eng.KeyStroke(k)
                eng.KeyStroke(break_bar[backend])
                eng.KeyStrokeL("<esc>:wincmd k<cr>")
                eng.KeyStrokeL(":e src/test.cpp\n")
                eng.KeyStrokeL(":10<cr>")
                eng.KeyStrokeL("<f8>")

                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertEqual([5, 10], breaks)

                # Go to another file
                eng.KeyStroke(":e src/lib.hpp\n")
                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertEqual([], breaks)
                eng.KeyStroke(":8\n")
                eng.KeyStrokeL("<f8>")
                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertEqual([8], breaks)

                # Return to the first file
                eng.KeyStroke(":e src/test.cpp\n")
                cur, breaks = eng.GetSigns()
                self.assertEqual(-1, cur)
                self.assertEqual([5, 10], breaks)

                eng.KeyStrokeL('ZZ')

if __name__ == "__main__":
    unittest.main()
