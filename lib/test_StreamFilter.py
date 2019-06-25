import pytest
from StreamFilter import StreamFilter


def test_filter():
    f = StreamFilter(b"\n(gdb) ")
    assert (b"", None) == f.filter(b"  server nvim-gdb-breakpoint")
    assert (b"", None) == f.filter(b"foo-bar")
    assert (b"", b'  server nvim-gdb-breakpointfoo-bar\n(gdb)') == f.filter(b"\n(gdb) ")

def test_timeout():
    f = StreamFilter(b"qwer")
    assert (b"", None) == f.filter(b"asdf")
    assert (b"", None) == f.filter(b"xyz")
    assert b"asdfxyz" == f.timeout()

def test_update_finish():
    f = StreamFilter(b"\nXXXX ")
    assert (b"", None) == f.filter(b"  server nvim-gdb-breakpoint")
    assert (b"", None) == f.filter(b"foo-bar")
    f.updateFinishMatcher(b"\n(gdb) ")
    assert (b"", b'  server nvim-gdb-breakpointfoo-bar\n(gdb)') == f.filter(b"\n(gdb) ")
