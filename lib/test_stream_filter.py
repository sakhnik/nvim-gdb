'''Test StreamFilter operation.'''
import re
from stream_filter import StreamFilter


def test_filter():
    '''Smoke.'''
    filt = StreamFilter(re.compile(rb"\n\(gdb\) "))
    assert (b"", None) == filt.filter(b"  server nvim-gdb-breakpoint")
    assert (b"", None) == filt.filter(b"foo-bar")
    assert (b"", b'  server nvim-gdb-breakpointfoo-bar\n(gdb) ') \
        == filt.filter(b"\n(gdb) ")


def test_timeout():
    '''Timeout.'''
    filt = StreamFilter(re.compile(b"qwer"))
    assert (b"", None) == filt.filter(b"asdf")
    assert (b"", None) == filt.filter(b"xyz")
    assert filt.timeout() == b"asdfxyz"


def test_update_finish():
    '''End matcher update.'''
    filt = StreamFilter(re.compile(b"\nXXXX "))
    assert (b"", None) == filt.filter(b"  server nvim-gdb-breakpoint")
    assert (b"", None) == filt.filter(b"foo-bar")
    filt.update_finish_matcher(re.compile(rb"\n\(gdb\) "))
    assert (b"", b'  server nvim-gdb-breakpointfoo-bar\n(gdb) ') \
        == filt.filter(b"\n(gdb) ")
