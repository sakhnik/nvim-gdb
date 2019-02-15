
def test_smoke(eng, backend):
    eng.feed(backend['launch'], 1000)
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 2000)
    eng.feed('<esc>')

    assert {'cur': 'test.cpp:17'} == eng.getSigns()

    eng.feed('<f10>')
    assert {'cur': 'test.cpp:19'} == eng.getSigns()

    eng.feed('<f11>')
    assert {'cur': 'test.cpp:10'} == eng.getSigns()

    eng.feed('<c-p>')
    assert {'cur': 'test.cpp:19'} == eng.getSigns()

    eng.feed('<c-n>')
    assert {'cur': 'test.cpp:10'} == eng.getSigns()

    eng.feed('<f12>')
    signs = eng.getSigns()
    assert 1 == len(signs)
    # different for different compilers
    assert signs["cur"] in {'test.cpp:17', 'test.cpp:19'}

    eng.feed('<f5>')
    assert {} == eng.getSigns()

def test_breaks(eng, backend):
    # Test toggling breakpoints.
    # TODO: Investigate socket connection race when the delay is small
    # here, like 1ms
    eng.feed(backend['launch'], 1000)
    eng.feed('<esc><c-w>k')
    eng.feed(":e src/test.cpp\n")
    eng.feed(':5<cr>')
    eng.feed('<f8>', 100)
    assert {'break': {1: [5]}} == eng.getSigns()

    eng.exe("GdbRun", 1000)
    assert {'cur': 'test.cpp:5', 'break': {1: [5]}} == eng.getSigns()

    eng.feed('<f8>')
    assert {'cur': 'test.cpp:5'} == eng.getSigns()

def test_interrupt(eng, backend):
    # Test interrupt.
    eng.feed(backend['launch'], 1000)
    eng.feed('run 4294967295\n', 1000)
    eng.feed('<esc>')
    eng.feed(':GdbInterrupt\n', 300)
    assert {'cur': 'test.cpp:22'} == eng.getSigns()

def test_until(eng, backend):
    eng.feed(backend['launch'], 1000)
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':21<cr>')
    eng.feed('<f4>')
    assert {'cur': 'test.cpp:21'} == eng.getSigns()

def test_program_exit(eng, backend):
    # Test the cursor is hidden after program end.
    eng.feed(backend['launch'], 1000)
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<f5>')
    assert {} == eng.getSigns()

def test_eval(eng, backend):
    # Test eval <cword>.
    eng.feed(backend['launch'], 1000)
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed('<f10>')

    eng.feed('^<f9>')
    assert 'print Foo' == eng.eval('GdbTestPeek("lastCommand")')

    eng.feed('/Lib::Baz\n')
    eng.feed('vt(')
    eng.feed(':GdbEvalRange\n')
    assert 'print Lib::Baz' == eng.eval('GdbTestPeek("lastCommand")')
