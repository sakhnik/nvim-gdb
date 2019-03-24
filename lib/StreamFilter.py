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


class Filter:
    """Pass-through filter."""
    def Filter(self, input):
        """Process input, filter between tokens, return the output."""
        return input, None

    def Timeout(self):
        """Process timeout, return whatever was kept in the buffer."""
        return b''


class StreamFilter(Filter):
    """Stream filter class: conceal output from now to the finish matcher."""

    def __init__(self, finish):
        """Initialize the filter with start and finish tokens."""
        self.buffer = bytearray()
        self.filtered = None
        self.UpdateFinishMatcher(finish)

    # Allow changing the termination sequence on the fly
    def UpdateFinishMatcher(self, finish):
        self.matcher = _StringMatcher(finish,
                                      self._Nop,
                                      self._FinishMatch,
                                      self._Nop)

    def _Nop(self, ch):
        self.buffer.append(ch)
        return False

    def _FinishMatch(self, ch):
        self.filtered = self.buffer
        self.buffer = bytearray()
        return False

    def Filter(self, input):
        """Process input, filter between tokens, return the output."""
        output = bytearray()
        for ch in input:
            action = self.matcher.match(ch)
            if action(ch):
                output.extend(self.buffer)
                self.buffer = bytearray()
        filtered = None
        if self.filtered:
            filtered = bytes(self.filtered)
            self.filtered = None
        return bytes(output), filtered

    def Timeout(self):
        """Process timeout, return whatever was kept in the buffer."""
        self.matcher.reset()
        output = self.buffer
        self.buffer = bytearray()
        return bytes(output)
