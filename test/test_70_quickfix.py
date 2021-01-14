'''Test loading backtrace and breakpoints into the quickfix.'''

import time
import pytest
import config


def test_breaks_backend(eng, backend):
    '''Breakpoint quickfix in C++.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed('b main\n')
    eng.feed('b Foo\n')
    eng.feed('b Bar\n')
    eng.feed('<esc>')
    eng.feed(':GdbCopenBreakpoints\n')
    time.sleep(0.3)
    eng.feed(':cc\n')
    assert eng.wait_for(lambda: eng.eval("line('.')"), \
            lambda r: r == 17) is None
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 10
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 5
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 5


def test_bt_backend(eng, backend):
    '''Backtrace quickfix in C++.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed('b Bar\n')
    eng.feed('run\n')
    assert eng.wait_signs({'cur': 'test.cpp:5', 'break': {1: [5]}}) is None
    eng.feed('<esc>')
    eng.feed(':GdbCopenBacktrace\n')
    time.sleep(0.3)
    eng.feed(':cc\n')
    assert eng.wait_for(lambda: eng.eval("line('.')"), \
            lambda r: r == 5) is None
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 12
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 19
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 19


def test_breaks_pdb(eng, post):
    '''Breakpoint quickfix in PDB.'''
    assert post
    eng.feed(' dp\n')
    assert eng.wait_paused() is None
    eng.feed('b _main\n')
    eng.feed('b _foo\n')
    eng.feed('b _bar\n')
    eng.feed('<esc>')
    eng.feed(':GdbCopenBreakpoints\n')
    time.sleep(0.3)
    eng.feed(':cc\n')
    assert eng.wait_for(lambda: eng.eval("line('.')"), \
            lambda r: r == 14) is None
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 8
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 4
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 4


def test_bt_pdb(eng, post):
    '''Backtrace quickfix in PDB.'''
    assert post
    eng.feed(' dp\n')
    assert eng.wait_paused() is None
    eng.feed('b _bar\n')
    eng.feed('cont\n')
    assert eng.wait_signs({'cur': 'main.py:5', 'break': {1: [4]}}) is None
    eng.feed('<esc>')
    eng.feed(':GdbCopenBacktrace\n')
    time.sleep(0.3)
    eng.feed(':cn\n')
    eng.feed(':cn\n')
    assert eng.wait_for(lambda: eng.eval("line('.')"), \
            lambda r: r == 22) is None
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 16
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 11
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 5


@pytest.mark.skipif("bashdb" not in config.BACKEND_NAMES,
                    reason="No bashdb")
def test_breaks_bashdb(eng, post):
    '''Breakpoint quickfix in BashDB.'''
    assert post
    eng.feed(' db\n')
    assert eng.wait_paused() is None
    eng.feed('b Main\n')
    eng.feed('b Foo\n')
    eng.feed('b Bar\n')
    eng.feed('<esc>')
    eng.feed(':GdbCopenBreakpoints\n')
    time.sleep(0.3)
    eng.feed(':cc\n')
    assert eng.wait_for(lambda: eng.eval("line('.')"), \
            lambda r: r == 16) is None
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 7
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 3
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 3


@pytest.mark.skipif("bashdb" not in config.BACKEND_NAMES,
                    reason="No bashdb")
def test_bt_bashdb(eng, post):
    '''Breakpoint quickfix in BashDB.'''
    assert post
    eng.feed(' db\n')
    assert eng.wait_paused() is None
    eng.feed('b Bar\n')
    eng.feed('cont\n')
    assert eng.wait_signs({'cur': 'main.sh:3', 'break': {1: [3]}}) is None
    eng.feed('<esc>')
    eng.feed(':GdbCopenBacktrace\n')
    time.sleep(0.3)
    eng.feed(':cc\n')
    assert eng.wait_for(lambda: eng.eval("line('.')"), \
            lambda r: r == 3) is None
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 11
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 18
    eng.feed(':cnext\n')
    assert eng.eval("line('.')") == 22
