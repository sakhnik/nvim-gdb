'''Test loading backtrace and breakpoints into the location list.'''

import time
import pytest
import config


def test_breaks_backend(eng, backend, count_stops):
    '''Breakpoint location list in C++.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed('b main<cr>')
    eng.feed('b Foo<cr>')
    count_stops.reset()
    eng.feed('b Bar<cr>')
    assert count_stops.wait(1) is None
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':aboveleft GdbLopenBreakpoints\n')
    assert eng.wait_for(lambda: eng.eval("len(getloclist(0))"),
                        lambda r: r > 0) is None
    eng.feed('<c-w>k')
    eng.feed(':ll<cr>')
    assert eng.wait_for(lambda: eng.eval("line('.')"),
                        lambda r: r == 17) is None
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 10
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 5
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 5


def test_bt_backend(eng, backend):
    '''Backtrace location list in C++.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed('b Bar<cr>')
    eng.feed('run<cr>')
    assert eng.wait_signs({'cur': 'test.cpp:5', 'break': {1: [5]}}) is None
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':belowright GdbLopenBacktrace\n')
    assert eng.wait_for(lambda: eng.eval("len(getloclist(0))"),
                        lambda r: r > 0) is None
    eng.feed('<c-w>j')
    eng.feed(':ll<cr>')
    assert eng.wait_for(lambda: eng.eval("line('.')"),
                        lambda r: r == 5) is None
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 12
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 19


def test_breaks_pdb(eng, post, count_stops):
    '''Breakpoint location list in PDB.'''
    assert post
    eng.feed(' dp<cr>')
    assert count_stops.wait(1) is None
    eng.feed('b _main<cr>')
    assert count_stops.wait(2) is None
    eng.feed('b _foo<cr>')
    assert count_stops.wait(3) is None
    eng.feed('b _bar<cr>')
    assert count_stops.wait(4) is None
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':GdbLopenBreakpoints<cr>')
    assert eng.wait_for(lambda: eng.eval("len(getloclist(0))"),
                        lambda r: r > 0) is None
    eng.feed('<c-w>j')
    eng.feed(':ll<cr>')
    assert eng.wait_for(lambda: eng.eval("line('.')"),
                        lambda r: r == 14) is None
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 8
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 4
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 4


def test_bt_pdb(eng, post, count_stops):
    '''Backtrace location list in PDB.'''
    assert post
    eng.feed(' dp<cr>')
    assert count_stops.wait(1) is None
    eng.feed('b _bar<cr>')
    assert count_stops.wait(2) is None
    eng.feed('cont<cr>')
    assert eng.wait_signs({'cur': 'main.py:5', 'break': {1: [4]}}) is None
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':GdbLopenBacktrace<cr>')
    assert eng.wait_for(lambda: eng.eval("len(getloclist(0))"),
                        lambda r: r > 0) is None
    eng.feed('<c-w>j')
    eng.feed(':lnext<cr>')
    eng.feed(':lnext<cr>')
    assert eng.wait_for(lambda: eng.eval("line('.')"),
                        lambda r: r == 22) is None
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 16
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 11
    eng.feed(':lnext<cr>')
    assert eng.eval("line('.')") == 5


@pytest.mark.skipif("bashdb" not in config.BACKEND_NAMES,
                    reason="No bashdb")
def test_breaks_bashdb(eng, post):
    '''Breakpoint location list in BashDB.'''
    assert post
    eng.feed(' db\n')
    assert eng.wait_paused() is None
    eng.feed('b Main\n')
    eng.feed('b Foo\n')
    eng.feed('b Bar\n')
    eng.feed('<esc>')
    eng.feed(':GdbLopenBreakpoints\n')
    time.sleep(0.3)
    eng.feed('<c-w>k')
    eng.feed(':ll\n')
    assert eng.wait_for(lambda: eng.eval("line('.')"),
                        lambda r: r == 16) is None
    eng.feed(':lnext\n')
    assert eng.eval("line('.')") == 7
    eng.feed(':lnext\n')
    assert eng.eval("line('.')") == 3
    eng.feed(':lnext\n')
    assert eng.eval("line('.')") == 3


@pytest.mark.skipif("bashdb" not in config.BACKEND_NAMES,
                    reason="No bashdb")
def test_bt_bashdb(eng, post):
    '''Breakpoint location list in BashDB.'''
    assert post
    eng.feed(' db\n')
    assert eng.wait_paused() is None
    eng.feed('b Bar\n')
    eng.feed('cont\n')
    assert eng.wait_signs({'cur': 'main.sh:3', 'break': {1: [3]}}) is None
    eng.feed('<esc>')
    eng.feed(':GdbLopenBacktrace\n')
    time.sleep(0.3)
    eng.feed('<c-w>k')
    eng.feed(':ll\n')
    assert eng.wait_for(lambda: eng.eval("line('.')"),
                        lambda r: r == 3) is None
    eng.feed(':lnext\n')
    assert eng.eval("line('.')") == 11
    eng.feed(':lnext\n')
    assert eng.eval("line('.')") == 18
    eng.feed(':lnext\n')
    assert eng.eval("line('.')") == 22
