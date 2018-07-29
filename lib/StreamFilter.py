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

    def reset(self):
        self.idx = 0


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
        self.buffer.append(ch)
        return False

    def _StartHold(self, ch):
        self.buffer.append(ch)
        return False

    def _StartFail(self, ch):
        self.buffer.append(ch)
        # Send the buffer out
        return True

    def _StartMatch(self, ch):
        self.buffer.append(ch)
        self.state = self.rejecting
        return False

    def _FinishMatch(self, ch):
        self.buffer = bytearray()
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

    def Timeout(self):
        """Process timeout, return whatever was kept in the buffer."""
        self.state.reset()
        self.state = self.passing
        output = self.buffer
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

        def test_20_timeout(self):
            """Test timeout."""
            f = StreamFilter(b"asdf", b"qwer")
            self.assertEqual(b"zxcv", f.Filter(b"zxcv"))
            self.assertEqual(b"", f.Filter(b"asdf"))
            self.assertEqual(b"", f.Filter(b"xyz"))
            self.assertEqual(b"asdfxyz", f.Timeout())
            self.assertEqual(b"qwer", f.Filter(b"qwer"))

    unittest.main()
