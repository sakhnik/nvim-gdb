"""Filter the stream from within given pair of tokens."""


class Filter:
    """Pass-through filter."""
    def filter(self, data):
        """Process data, filter between tokens, return the output."""
        return data, None

    def timeout(self):
        """Process timeout, return whatever was kept in the buffer."""
        return b''


class StreamFilter(Filter):
    """Stream filter class: conceal output from now to the finish matcher."""

    def __init__(self, finish_re):
        """Initialize the filter with start and finish tokens."""
        self.buffer = bytearray()
        self.updateFinishMatcher(finish_re)

    # Allow changing the termination sequence on the fly
    def updateFinishMatcher(self, finish_re):
        self.matcher = finish_re

    # Accept the data: either append it to the buffer until
    # the final matcher has been met, or output the whole filtered buffer.
    # Returns a tuple (bytes to show, bytes suppressed until and including the finish matcher).
    def filter(self, data):
        """Process data, filter until the finish match, return the output."""
        filtered = None
        if not self.matcher:
            return data, None
        self.buffer.extend(data)
        # XXX: note that we are scanning over the buffer again and again
        # if this causes noticeable performance issue, consider maintaining
        # a smaller part of the buffer to scan.
        m = self.matcher.search(self.buffer)
        if m:
            self.matcher = None
            filtered = self.buffer[:m.end()]
            output = self.buffer[m.end():]
            self.buffer = bytearray()
            return output, filtered
        return b'', None

    def timeout(self):
        """Process timeout, return whatever was kept in the buffer."""
        if self.matcher:
            output = self.buffer
            self.buffer = bytearray()
            return bytes(output)
        else:
            return b''
