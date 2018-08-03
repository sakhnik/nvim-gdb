#!/usr/bin/env python
"""Test breakpoint manipulation."""

import os
import unittest
import engine


eng = engine.Engine()
subtests = {"gdb": [' dd', '\n'], "lldb": [' dl', '\n']}
break_main = {"gdb": "break main\n", "lldb": "breakpoint set --fullname main\n"}


class TestBreakpoint(unittest.TestCase):
    """Test class."""

    def test_10_detect(self):
        """=> Verify manual breakpoint is detected."""
        for backend, launch in subtests.items():
            with self.subTest(backend=backend):
                for k in launch:
                    eng.KeyStroke(k)
                eng.KeyStroke(break_main[backend])
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

        subs = {"gdb": ":GdbStart gdb -q %s\n" % exe_path,
                "lldb": ":GdbStartLLDB lldb %s\n" % exe_path}
        for backend, launch in subs.items():
            with self.subTest(backend=backend):
                try:
                    eng.KeyStroke(':cd /tmp\n')
                    eng.KeyStroke(launch)
                    eng.KeyStroke(break_main[backend])
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
        for backend, launch in subtests.items():
            with self.subTest(backend=backend):
                for k in launch:
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
