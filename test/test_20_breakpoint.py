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

                self.assertEqual(1, eng.Eval('len(t:gdb._breakpoints)'))
                p = os.path.abspath('src/test.cpp')
                self.assertEqual({'17': 1},
                                 eng.Eval('t:gdb._breakpoints["%s"]' % p))

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

                    self.assertEqual(1, eng.Eval('len(t:gdb._breakpoints)'))
                    p = os.path.abspath('src/test.cpp')
                    self.assertEqual({'17': 1},
                                     eng.Eval('t:gdb._breakpoints["%s"]' % p))

                    eng.KeyStrokeL('<esc>')
                    eng.KeyStrokeL('ZZ')
                finally:
                    eng.KeyStroke(':cd %s\n' % old_cwd)


if __name__ == "__main__":
    unittest.main()
