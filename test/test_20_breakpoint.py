#!/usr/bin/env python

import os
import unittest
import engine


eng = engine.Engine()
subtests = {"gdb": [' dd', '\n'], "lldb": [' dl', '\n']}


class TestBreakpoint(unittest.TestCase):

    def test_10_detect(self):
        ''' => Verify that manually set breakpoint is detected '''
        for k in subtests['gdb']:
            eng.KeyStroke(k)
        eng.KeyStroke('break main\n')

        self.assertEqual(1, eng.Eval('len(t:gdb._breakpoints)'))
        self.assertEqual({'16':'1'}, eng.Eval('t:gdb._breakpoints["%s"]' % os.path.abspath('src/test.cpp')))

        eng.KeyStrokeL('<esc>')
        eng.KeyStrokeL('ZZ')

if __name__ == "__main__":
    unittest.main()
