'''Test loading backtrace and breakpoints into the quickfix.'''

import time


def test_backend(eng, backend):
    '''Quickfix in C++.'''
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
