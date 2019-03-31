"""Filter the stream from within given pair of tokens."""


class _StringMatcher:
    def __init__(self, s):
        self.s = s
        self.idx = 0

    def match(self, ch):
        if self.s[self.idx] == ch:
            self.idx += 1
            if self.idx == len(self.s):
                self.idx = 0
                return True   # succeed
            return False      # hold
        self.idx = 0
        return False          # fail

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
        self.UpdateFinishMatcher(finish)

    # Allow changing the termination sequence on the fly
    def UpdateFinishMatcher(self, finish):
        self.matcher = _StringMatcher(finish)

    # Accept the input: either append it to the buffer until
    # the final matcher has been met, or output the whole filtered buffer.
    # Returns a tuple (bytes to show, bytes suppressed until and including the finish matcher).
    def Filter(self, input, buffer_callback=lambda _: None):
        """Process input, filter until the finish match, return the output."""
        filtered = None
        for ch in input:
            if self.matcher:
                if self.matcher.match(ch):
                    self.matcher = None
                    filtered = bytes(self.buffer)
                    self.buffer = bytearray()
                else:
                    self.buffer.append(ch)
                    buffer_callback(self.buffer)
            else:
                self.buffer.append(ch)
        if not self.matcher:
            output = bytes(self.buffer)
            self.buffer = bytearray()
            return output, filtered
        return b'', None

    def Timeout(self):
        """Process timeout, return whatever was kept in the buffer."""
        if self.matcher:
            self.matcher.reset()
            output = self.buffer
            self.buffer = bytearray()
            return bytes(output)
        else:
            return b''
