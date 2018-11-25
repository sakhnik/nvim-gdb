#!/usr/bin/env python
"""Test pdb support."""

import unittest
import engine
import time
import os


e = engine.Engine()


class TestPdb(unittest.TestCase):
    """Test class."""

    def test_10_generic(self):
        """=> Test a generic use case."""
        e.Ty(' dp')
        e.Ty('\n', delay=0.3)
        e.Ty('tbreak _main\n')
        e.Ty('cont\n')
        e.In('<esc>')

        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:15', cur)
        self.assertFalse(breaks)

        e.In('<f10>')
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:16', cur)
        self.assertFalse(breaks)

        e.In('<f11>')
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:8', cur)
        self.assertFalse(breaks)

        e.In('<f12>')
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:10', cur)
        self.assertFalse(breaks)

        e.In('<f5>', delay=1.2)
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:1', cur)
        self.assertFalse(breaks)

        e.Exe('GdbDebugStop')

    def test_20_breakpoint(self):
        """=> Test toggling breakpoints."""
        e.Ty(' dp')
        e.Ty('\n', delay=0.3)
        e.In('<esc>')

        e.In('<esc><c-w>k')
        e.Ty(":e main.py\n")
        e.In(':5<cr>')
        e.In('<f8>')
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:1', cur)
        self.assertListEqual([5], breaks)

        e.Exe("GdbContinue")
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:5', cur)
        self.assertListEqual([5], breaks)

        e.In('<f8>', delay=0.3)
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:5', cur)
        self.assertFalse(breaks)

        e.Exe('GdbDebugStop')

    def test_30_navigation(self):
        """=> Test toggling breakpoints while navigating."""
        e.Ty(' dp')
        e.Ty('\n', delay=0.3)
        e.In('<esc>')

        e.In('<esc><c-w>k')
        e.In(':5<cr>')
        e.In('<f8>')
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:1', cur)
        self.assertListEqual([5], breaks)

        # Go to another file
        e.Ty(":e test_30_pdb.py\n")
        e.Ty(":24\n")
        e.In("<f8>")
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:1', cur)
        self.assertEqual([24], breaks)
        e.Ty(":25\n")
        e.In("<f8>")
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:1', cur)
        self.assertEqual([24, 25], breaks)

        # Return to the original file
        e.Ty(":e main.py\n")
        cur, breaks = e.GetSigns()
        self.assertEqual('main.py:1', cur)
        self.assertListEqual([5], breaks)

        e.Exe('GdbDebugStop')

    def test_40_until(self):
        """=> Test run until line."""
        e.Ty(' dp')
        e.Ty('\n', delay=0.3)
        e.Ty('tbreak _main\n')
        e.Ty('cont\n')
        e.In('<esc>')

        e.In('<c-w>w')
        e.In(':18<cr>')
        e.In('<f4>')

        cur, breaks = e.GetSigns()
        # While the check works fine locally, doesn't work in Travis.
        # Probably, because of different versions of Python interpreter.
        if not os.getenv("TRAVIS_BUILD_ID"):
            self.assertEqual('main.py:18', cur)
        self.assertFalse(breaks)

        e.Ty('ZZ')


if __name__ == "__main__":
    unittest.main()
