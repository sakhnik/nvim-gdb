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
        self.buffer = ''

    def _Nop(self, ch):
        return False

    def _StartHold(self, ch):
        self.buffer += ch
        return False

    def _StartFail(self, ch):
        # Send the buffer out
        self.buffer += ch
        return True

    def _StartMatch(self, ch):
        self.buffer = ''
        self.state = self.rejecting
        return False

    def _FinishMatch(self, ch):
        self.state = self.passing
        return False

    def Filter(self, input):
        """Process input, filter between tokens, return the output."""
        output = ''
        for ch in input:
            action = self.state.match(ch)
            if action(ch):
                output += self.buffer
                self.buffer = ''
        return output


if __name__ == "__main__":
    import unittest

    class TestFilter(unittest.TestCase):
        """Test class."""

        def test_10_first(self):
            """Test a generic scenario."""
            f = StreamFilter("  server nvim-gdb-", "\n(gdb) ")
            self.assertEqual("hello", f.Filter("hello"))
            self.assertEqual(" world", f.Filter(" world"))
            self.assertEqual("", f.Filter("  "))
            self.assertEqual("  again", f.Filter("again"))
            self.assertEqual("", f.Filter("  server nvim-gdb-breakpoint"))
            self.assertEqual("", f.Filter("foo-bar"))
            self.assertEqual("", f.Filter("\n(gdb) "))
            self.assertEqual("asdf", f.Filter("asdf"))

    unittest.main()
