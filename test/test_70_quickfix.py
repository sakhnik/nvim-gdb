'''Test loading backtrace and breakpoints into the quickfix.'''

import time


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
