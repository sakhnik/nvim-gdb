'''Test quitting the debugging session.'''

# pylint: disable=redefined-outer-name

import pytest


@pytest.fixture(scope='function')
def setup(eng):
    '''The fixture for quit tests.'''
    num_bufs = eng.count_buffers()
    eng.feed(":GdbStart ./dummy-gdb.sh<cr>")
    eng.feed('<esc>')
    yield True
    # Check that no new buffers have left
    assert num_bufs == eng.count_buffers()
    assert eng.eval("tabpagenr('$')") == 1


def test_gdb_debug_stop(setup, eng):
    '''Quit with the command GdbDebugStop.'''
    assert setup
    eng.feed(":GdbDebugStop<cr>")


def test_gdb_eof(setup, eng):
    '''Quit with ctrl-d.'''
    assert setup
    eng.feed("i<c-d>")


def test_gdb_tabclose(setup, eng):
    '''Quit by closing the tab.'''
    assert setup
    eng.feed("GdbStart ./dummy-gdb.sh<cr>")
    eng.feed('<esc>')
    eng.feed(":tabclose<cr>")
    eng.feed(":GdbDebugStop<cr>")


def test_sticky_term(setup, eng):
    '''GDB terminal survives closing.'''
    assert setup
    assert 2 == len(eng.eval("nvim_list_wins()"))
    eng.feed(":q<cr>")
    assert 2 == len(eng.eval("nvim_list_wins()"))
    eng.feed(":GdbDebugStop<cr>")


@pytest.fixture(scope='function')
def non_sticky(eng):
    '''The fixture to disable terminal stickiness.'''
    eng.feed(":let g:nvimgdb_sticky_dbg_buf = v:false<cr>")
    yield True
    eng.feed(":unlet g:nvimgdb_sticky_dbg_buf<cr>")


def test_elusive_term(non_sticky, setup, eng):
    '''GDB terminal can be closed.'''
    assert non_sticky
    assert setup
    assert 2 == len(eng.eval("nvim_list_wins()"))
    eng.feed(":q<cr>")
    assert 1 == len(eng.eval("nvim_list_wins()"))
    eng.feed(":GdbDebugStop<cr>")
