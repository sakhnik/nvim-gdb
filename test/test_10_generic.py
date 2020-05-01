'''Test generic operation.'''


def test_smoke(eng, backend):
    '''Smoke.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n')
    eng.feed('<esc>')

    assert eng.wait_signs({'cur': 'test.cpp:17'}, 2000) is None

    eng.feed('<f10>')
    assert {'cur': 'test.cpp:19'} == eng.get_signs()

    eng.feed('<f11>')
    assert {'cur': 'test.cpp:10'} == eng.get_signs()

    eng.feed('<c-p>')
    assert eng.wait_signs({'cur': 'test.cpp:19'}) is None

    eng.feed('<c-n>')
    assert {'cur': 'test.cpp:10'} == eng.get_signs()

    eng.feed('<f12>')
    signs = eng.get_signs()
    assert len(signs) == 1
    # different for different compilers
    assert signs["cur"] in {'test.cpp:17', 'test.cpp:19'}

    eng.feed('<f5>')
    assert eng.wait_signs({}) is None


def test_breaks(eng, backend):
    '''Test toggling breakpoints.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed('<esc><c-w>w')
    eng.feed(":e src/test.cpp\n")
    eng.feed(':5<cr>')
    eng.feed('<f8>', 100)
    assert {'break': {1: [5]}} == eng.get_signs()

    eng.exe("GdbRun")
    assert eng.wait_signs({'cur': 'test.cpp:5', 'break': {1: [5]}}) is None

    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'test.cpp:5'}) is None


def test_interrupt(eng, backend):
    '''Test interrupt.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed('run 4294967295\n', 1000)
    eng.feed('<esc>')
    eng.feed(':GdbInterrupt\n')
    assert eng.wait_signs({'cur': 'test.cpp:22'}) is None


def test_until(eng, backend):
    '''Test run until.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':21<cr>')
    eng.feed('<f4>')
    assert eng.wait_signs({'cur': 'test.cpp:21'}) is None


def test_program_exit(eng, backend):
    '''Test the cursor is hidden after program end.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<f5>')
    assert {} == eng.get_signs()


def test_eval(eng, backend):
    '''Test eval <cword>.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed('<f10>')

    eng.feed('^<f9>')
    assert eng.eval('GdbTestPeek("_last_command")') == 'print Foo'

    eng.feed('/Lib::Baz\n')
    eng.feed('vt(')
    eng.feed(':GdbEvalRange\n')
    assert eng.eval('GdbTestPeek("_last_command")') == 'print Lib::Baz'


def test_navigate(eng, backend):
    '''Test navigating to another file.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed('/Lib::Baz\n')
    eng.feed('<f4>')
    eng.feed('<f11>')

    eng.feed(':e src/test.cpp')
    assert {'cur': 'lib.hpp:7'} == eng.get_signs()
