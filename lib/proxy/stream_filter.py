"""Filter the stream from within given pair of tokens."""

import re
import bisect


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

    CSEQ_STR = rb'\[[^a-zA-Z]*[a-zA-Z]'
    CSEQ = re.compile(CSEQ_STR)

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

        # We'd like to preserve colouring in self.buffer, but allow filtering
        # for the side channel without control sequences.

        # Copy the buffer chunks without control sequences
        buffer_no_cs = bytearray()
        # Chunks offsets in self.buffer
        offsets_buffer = []
        # Corresponding offsets in buffer_no_cs
        offsets_buffer_no_cs = []
        # Current offset in self.buffer while iterating over CSEQ.
        offset = 0
        for m in re.finditer(self.CSEQ, self.buffer):
            if m.start() > offset:
                # Copy over the chunk until a CSEQ start and remember
                # the offsets
                offsets_buffer_no_cs.append(len(buffer_no_cs))
                offsets_buffer.append(offset)
                buffer_no_cs.extend(self.buffer[offset:m.start()])
            offset = m.end()
        # Copy the rest of the buffer into the search buffer buffer_no_cs
        if offset < len(self.buffer):
            offsets_buffer_no_cs.append(len(buffer_no_cs))
            offsets_buffer.append(offset)
            buffer_no_cs.extend(self.buffer[offset:])

        # Note that we are scanning over the buffer again and again
        # if this causes noticeable performance issue, consider maintaining
        # a smaller part of the buffer to scan.
        match = self.matcher.search(buffer_no_cs)
        if match:
            # We've just found the boundaries of the desired output.
            self.matcher = None
            filtered = bytes(buffer_no_cs[:match.end()])
            # Find corresponding offset in the original buffer to remove
            # whatever corresponded to the found message.
            idx = bisect.bisect_left(offsets_buffer_no_cs, match.end())
            assert idx > 0
            offset_rest = offsets_buffer[idx-1] + match.end() - offsets_buffer_no_cs[idx-1]
            output = bytes(self.buffer[offset_rest:])
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
