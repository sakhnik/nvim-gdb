#!/usr/bin/env python

import unittest
import engine


eng = engine.Engine()


class TestQuit(unittest.TestCase):
    """Test class."""

    def setUp(self):
        self.numBufs = eng.countBuffers()
        eng.feed(":GdbStart ./dummy-gdb.sh<cr>")
        eng.feed('<esc>')

    def tearDown(self):
        # Check that no new buffers have left
        self.assertEqual(self.numBufs, eng.countBuffers())
        self.assertEqual(1, eng.eval("tabpagenr('$')"))

    def test_gdb_debug_stop(self):
        eng.feed(":GdbDebugStop<cr>")

    def test_terminal_ZZ(self):
        eng.feed("ZZ")

    def test_jump_ZZ(self):
        eng.feed("<c-w>w")
        eng.feed("ZZ")


if __name__ == "__main__":
    unittest.main()
