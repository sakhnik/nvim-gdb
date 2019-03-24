import pytest
from StreamFilter import StreamFilter


def test_filter():
    f = StreamFilter(b"  server nvim-gdb-", b"\n(gdb) ")
    assert (b"hello", None) == f.Filter(b"hello")
    assert (b" world", None) == f.Filter(b" world")
    assert (b"", None) == f.Filter(b"  ")
    assert (b"  again", None) == f.Filter(b"again")
    assert (b"", None) == f.Filter(b"  server nvim-gdb-breakpoint")

    assert (b"", None) == f.Filter(b"foo-bar")
    assert (b"", b'  server nvim-gdb-breakpointfoo-bar\n(gdb)') == f.Filter(b"\n(gdb) ")
    assert (b"asdf", None) == f.Filter(b"asdf")

def test_timeout():
    f = StreamFilter(b"asdf", b"qwer")
    assert (b"zxcv", None) == f.Filter(b"zxcv")
    assert (b"", None) == f.Filter(b"asdf")
    assert (b"", None) == f.Filter(b"xyz")
    assert b"asdfxyz" == f.Timeout()
    assert (b"qwer", None) == f.Filter(b"qwer")
