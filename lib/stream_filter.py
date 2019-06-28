"""Filter the stream from within given pair of tokens."""


class Filter:
    """Pass-through filter."""
    def filter(self, data):
        """Process data, filter between tokens, return the output."""
        self._calm_the_linter()
        return data, None

    def timeout(self):
        """Process timeout, return whatever was kept in the buffer."""
        self._calm_the_linter()
        return b''

    @staticmethod
    def _calm_the_linter():
        pass


class StreamFilter(Filter):
    """Stream filter class: conceal output from now to the finish matcher."""

    def __init__(self, finish_re):
        """Initialize the filter with start and finish tokens."""
        self.buffer = bytearray()
        self.matcher = finish_re

    def update_finish_matcher(self, finish_re):
        '''Allow changing the termination sequence on the fly.'''
        self.matcher = finish_re

    # Accept the data: either append it to the buffer until
    # the final matcher has been met, or output the whole filtered buffer.
    # Returns a tuple (bytes to show, bytes suppressed until and including
    # the finish matcher).
    def filter(self, data):
        """Process data, filter until the finish match, return the output."""
        filtered = None
        if not self.matcher:
            return data, None
        self.buffer.extend(data)
        # Note that we are scanning over the buffer again and again
        # if this causes noticeable performance issue, consider maintaining
        # a smaller part of the buffer to scan.
        match = self.matcher.search(self.buffer)
        if match:
            self.matcher = None
            filtered = bytes(self.buffer[:match.end()])
            output = bytes(self.buffer[match.end():])
            self.buffer = bytearray()
            return output, filtered
        return b'', None

    def timeout(self):
        """Process timeout, return whatever was kept in the buffer."""
        if self.matcher:
            output = self.buffer
            self.buffer = bytearray()
            return bytes(output)
        return b''
