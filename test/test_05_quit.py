import pytest


@pytest.fixture(scope='function')
def setup(eng):
    numBufs = eng.countBuffers()
    eng.feed(":GdbStart ./dummy-gdb.sh<cr>")
    eng.feed('<esc>')
    yield
    # Check that no new buffers have left
    assert numBufs == eng.countBuffers()
    assert 1 == eng.eval("tabpagenr('$')")


def test_gdb_debug_stop(setup, eng):
    eng.feed(":GdbDebugStop<cr>")

def test_terminal_ZZ(setup, eng):
    eng.feed("ZZ")

def test_jump_ZZ(setup, eng):
    eng.feed("<c-w>w")
    eng.feed("ZZ")
