"""Filter the stream from within given pair of tokens."""


class _StringMatcher:
    def __init__(self, s, hold, succeed, fail):
        self.s = s
        self.hold = hold
        self.succeed = succeed
        self.fail = fail
        self.idx = 0

    def match(self, ch):
        if self.s[self.idx] == ch:
            self.idx += 1
            if self.idx == len(self.s):
                self.idx = 0
                return self.succeed
            return self.hold
        self.idx = 0
        return self.fail


class StreamFilter:
    """Stream filter class."""

    def __init__(self, start, finish):
        """Initialize the filter with start and finish tokens."""
        self.passing = _StringMatcher(start,
                                      self._StartHold,
                                      self._StartMatch,
                                      self._StartFail)
        self.rejecting = _StringMatcher(finish,
                                        self._Nop,
                                        self._FinishMatch,
                                        self._Nop)
        self.state = self.passing
        self.buffer = bytearray()

    def _Nop(self, ch):
        return False

    def _StartHold(self, ch):
        self.buffer.append(ch)
        return False

    def _StartFail(self, ch):
        # Send the buffer out
        self.buffer.append(ch)
        return True

    def _StartMatch(self, ch):
        self.buffer = bytearray()
        self.state = self.rejecting
        return False

    def _FinishMatch(self, ch):
        self.state = self.passing
        return False

    def Filter(self, input):
        """Process input, filter between tokens, return the output."""
        output = bytearray()
        for ch in input:
            action = self.state.match(ch)
            if action(ch):
                output.extend(self.buffer)
                self.buffer = bytearray()
        return bytes(output)


if __name__ == "__main__":
    import unittest

    class TestFilter(unittest.TestCase):
        """Test class."""

        def test_10_first(self):
            """Test a generic scenario."""
            f = StreamFilter(b"  server nvim-gdb-", b"\n(gdb) ")
            self.assertEqual(b"hello", f.Filter(b"hello"))
            self.assertEqual(b" world", f.Filter(b" world"))
            self.assertEqual(b"", f.Filter(b"  "))
            self.assertEqual(b"  again", f.Filter(b"again"))
            self.assertEqual(b"", f.Filter(b"  server nvim-gdb-breakpoint"))
            self.assertEqual(b"", f.Filter(b"foo-bar"))
            self.assertEqual(b"", f.Filter(b"\n(gdb) "))
            self.assertEqual(b"asdf", f.Filter(b"asdf"))

    unittest.main()
