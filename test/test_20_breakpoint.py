#!/usr/bin/env python
"""Test breakpoint manipulation."""

import os
import unittest
import engine
import config


e = engine.Engine()

subtests = {}
if "gdb" in config.debuggers:
    subtests['gdb'] = {'launch': ' dd\n',
                       'break_main': 'break main\n'}
if "lldb" in config.debuggers:
    subtests['lldb'] = {'launch': ' dl\n',
                        'break_main': 'breakpoint set --fullname main\n'}


class TestBreakpoint(unittest.TestCase):
    """Test class."""

    def test_10_detect(self):
        """=> Verify manual breakpoint is detected."""
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec["launch"], delay=1)
                e.Ty(spec["break_main"])
                e.Ty('run\n', delay=1)

                cur, breaks = e.GetSigns()
                self.assertEqual('test.cpp:17', cur)
                self.assertEqual([17], breaks)

                e.In('<esc>')
                e.In('ZZ')

    def test_20_cd(self):
        """=> Verify manual breakpoint is detected from a random directory."""
        exe_path = os.path.abspath('a.out')
        old_cwd = os.getcwd()

        subs = {'gdb': ":GdbStart gdb -q %s\n" % exe_path,
                'lldb': ":GdbStartLLDB lldb %s\n" % exe_path}

        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                try:
                    e.Ty(':cd /tmp\n')
                    e.Ty(subs[backend], delay=1)
                    e.Ty(subtests[backend]["break_main"])
                    e.Ty('run\n', delay=1)

                    cur, breaks = e.GetSigns()
                    self.assertEqual('test.cpp:17', cur)
                    self.assertEqual([17], breaks)

                    e.In('<esc>')
                    e.In('ZZ')
                finally:
                    e.Ty(':cd %s\n' % old_cwd)

    def test_30_navigate(self):
        """=> Verify that breakpoints stay when source code is navigated."""
        break_bar = {"gdb": "break Bar\n", "lldb": "breakpoint set --fullname Bar\n"}
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec['launch'], delay=1)
                e.Ty(break_bar[backend])
                e.In("<esc>:wincmd k<cr>")
                e.In(":e src/test.cpp\n")
                e.In(":10<cr>")
                e.In("<f8>")

                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertEqual([5, 10], breaks)

                # Go to another file
                e.Ty(":e src/lib.hpp\n")
                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertEqual([], breaks)
                e.Ty(":8\n")
                e.In("<f8>")
                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertEqual([8], breaks)

                # Return to the first file
                e.Ty(":e src/test.cpp\n")
                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertEqual([5, 10], breaks)

                e.In('ZZ')

    def test_40_clear_all(self):
        """=> Verify that can clear all breakpoints."""
        break_bar = {"gdb": "break Bar\n", "lldb": "breakpoint set --fullname Bar\n"}
        for backend, spec in subtests.items():
            with self.subTest(backend=backend):
                e.Ty(spec['launch'], delay=1)
                e.Ty(break_bar[backend])
                e.Ty(spec['break_main'])
                e.In("<esc>:wincmd k<cr>")
                e.In(":e src/test.cpp\n")
                e.In(":10<cr>")
                e.In("<f8>")

                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertEqual([5, 10, 17], breaks)

                e.Ty(":GdbBreakpointClearAll\n", delay=1)
                cur, breaks = e.GetSigns()
                self.assertFalse(cur)
                self.assertFalse(breaks)

                e.In('ZZ')


if __name__ == "__main__":
    unittest.main()
