#!/usr/bin/env python
"""Test pdb support."""

import unittest
import engine
import time


eng = engine.Engine()


class TestPdb(unittest.TestCase):
    """Test class."""

    def test_10_generic(self):
        """=> Test a generic use case."""
        eng.KeyStroke(' dp')
        eng.KeyStroke('\n', delay=0.3)
        eng.KeyStroke('tbreak _main\n')
        eng.KeyStroke('cont\n')
        eng.KeyStrokeL('<esc>')

        cur, breaks = eng.GetSigns()
        self.assertEqual(15, cur)
        self.assertFalse(breaks)

        eng.KeyStrokeL('<f10>')
        cur, breaks = eng.GetSigns()
        self.assertEqual(16, cur)
        self.assertFalse(breaks)

        eng.KeyStrokeL('<f11>')
        cur, breaks = eng.GetSigns()
        self.assertEqual(8, cur)
        self.assertFalse(breaks)

        eng.KeyStrokeL('<f12>')
        cur, breaks = eng.GetSigns()
        self.assertEqual(10, cur)
        self.assertFalse(breaks)

        eng.KeyStrokeL('<f5>', delay=1)
        cur, breaks = eng.GetSigns()
        self.assertEqual(1, cur)
        self.assertFalse(breaks)

        eng.Command('GdbDebugStop')

    def test_20_breakpoint(self):
        """=> Test toggling breakpoints."""
        eng.KeyStroke(' dp')
        eng.KeyStroke('\n', delay=0.3)
        eng.KeyStrokeL('<esc>')

        eng.KeyStrokeL('<esc><c-w>k')
        eng.KeyStroke(":e main.py\n")
        eng.KeyStrokeL(':5<cr>')
        eng.KeyStrokeL('<f8>')
        cur, breaks = eng.GetSigns()
        self.assertEqual(1, cur)
        self.assertListEqual([5], breaks)

        eng.Command("GdbContinue")
        cur, breaks = eng.GetSigns()
        self.assertEqual(5, cur)
        self.assertListEqual([5], breaks)

        eng.KeyStrokeL('<f8>', delay=0.3)
        cur, breaks = eng.GetSigns()
        self.assertEqual(5, cur)
        self.assertFalse(breaks)

        eng.Command('GdbDebugStop')

    def test_30_navigation(self):
        """=> Test toggling breakpoints while navigating."""
        eng.KeyStroke(' dp')
        eng.KeyStroke('\n', delay=0.3)
        eng.KeyStrokeL('<esc>')

        eng.KeyStrokeL('<esc><c-w>k')
        eng.KeyStroke(":e main.py\n")
        eng.KeyStrokeL(':5<cr>')
        eng.KeyStrokeL('<f8>')
        cur, breaks = eng.GetSigns()
        self.assertEqual(1, cur)
        self.assertListEqual([5], breaks)

        # Go to another file
        eng.KeyStroke(":e test_30_pdb.py\n")
        eng.KeyStroke(":23\n")
        eng.KeyStrokeL("<f8>")
        cur, breaks = eng.GetSigns()
        # TODO: fix this
        #self.assertEqual(-1, cur)
        self.assertEqual([23], breaks)
        eng.KeyStroke(":24\n")
        eng.KeyStrokeL("<f8>")
        cur, breaks = eng.GetSigns()
        #self.assertEqual(-1, cur)
        self.assertEqual([23, 24], breaks)

        # Return to the original file
        eng.KeyStroke(":e main.py\n")
        cur, breaks = eng.GetSigns()
        self.assertEqual(1, cur)
        self.assertListEqual([5], breaks)

        eng.Command('GdbDebugStop')

    def test_40_until(self):
        """=> Test run until line."""
        eng.KeyStroke(' dp')
        eng.KeyStroke('\n', delay=0.3)
        eng.KeyStroke('tbreak _main\n')
        eng.KeyStroke('cont\n')
        eng.KeyStrokeL('<esc>')

        eng.KeyStrokeL('<c-w>w')
        eng.KeyStrokeL(':18<cr>')
        eng.KeyStrokeL('<f4>')

        cur, breaks = eng.GetSigns()
        # TODO: Fix in Travis
        #self.assertEqual(18, cur)
        self.assertFalse(breaks)

        eng.KeyStroke('ZZ')


if __name__ == "__main__":
    unittest.main()
