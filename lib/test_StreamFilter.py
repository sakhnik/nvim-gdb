import pytest
from StreamFilter import StreamFilter


def test_filter():
    f = StreamFilter(b"\n(gdb) ")
    assert (b"", None) == f.Filter(b"  server nvim-gdb-breakpoint")
    assert (b"", None) == f.Filter(b"foo-bar")
    assert (b"", b'  server nvim-gdb-breakpointfoo-bar\n(gdb)') == f.Filter(b"\n(gdb) ")

def test_timeout():
    f = StreamFilter(b"qwer")
    assert (b"", None) == f.Filter(b"asdf")
    assert (b"", None) == f.Filter(b"xyz")
    assert b"asdfxyz" == f.Timeout()

def test_update_finish():
    f = StreamFilter(b"\nXXXX ")
    assert (b"", None) == f.Filter(b"  server nvim-gdb-breakpoint")
    assert (b"", None) == f.Filter(b"foo-bar")
    f.UpdateFinishMatcher(b"\n(gdb) ")
    assert (b"", b'  server nvim-gdb-breakpointfoo-bar\n(gdb)') == f.Filter(b"\n(gdb) ")
