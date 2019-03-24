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
    """Stream filter class."""

    def __init__(self, start, finish):
        """Initialize the filter with start and finish tokens."""
        self.passing = _StringMatcher(start,
                                      self._StartHold,
                                      self._StartMatch,
                                      self._StartFail)
        self.state = self.passing
        self.buffer = bytearray()
        self.filtered = None
        self.UpdateFinishMatcher(finish)

    # Allow changing the termination sequence on the fly
    def UpdateFinishMatcher(self, finish):
        self.rejecting = _StringMatcher(finish,
                                        self._Nop,
                                        self._FinishMatch,
                                        self._Nop)
        # Make sure the new rejecting matcher is updated if the previous
        # one was active.
        if self.state != self.passing:
            self.state = self.rejecting

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
        self.filtered = self.buffer
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
        filtered = None
        if self.filtered:
            filtered = bytes(self.filtered)
            self.filtered = None
        return bytes(output), filtered

    def Timeout(self):
        """Process timeout, return whatever was kept in the buffer."""
        self.state.reset()
        self.state = self.passing
        output = self.buffer
        self.buffer = bytearray()
        return bytes(output)
