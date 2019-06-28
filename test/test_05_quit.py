import pytest


@pytest.fixture(scope='function')
def setup(eng):
    '''The fixture for quit tests.'''
    num_bufs = eng.count_buffers()
    eng.feed(":GdbStart ./dummy-gdb.sh<cr>")
    eng.feed('<esc>')
    yield
    # Check that no new buffers have left
    assert num_bufs == eng.count_buffers()
    assert eng.eval("tabpagenr('$')") == 1


def test_gdb_debug_stop(setup, eng):
    '''Quit with the command GdbDebugStop.'''
    eng.feed(":GdbDebugStop<cr>")


def test_terminal_ZZ(setup, eng):
    '''Quit with ZZ.'''
    eng.feed("ZZ")


def test_jump_ZZ(setup, eng):
    '''Quit with ZZ from the jump window.'''
    eng.feed("<c-w>w")
    eng.feed("ZZ")
