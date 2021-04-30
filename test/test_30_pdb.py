'''Test PDB support.'''


def test_smoke(eng, post, terminal_end):
    '''Test a generic use case.'''
    assert post
    assert terminal_end
    eng.feed(' dp')
    eng.feed('\n', 1000)
    eng.feed('tbreak _main\n')
    eng.feed('cont\n')
    eng.feed('<esc>')

    assert eng.wait_signs({'cur': 'main.py:15'}) is None

    eng.feed('<f10>')
    assert eng.wait_signs({'cur': 'main.py:16'}) is None

    eng.feed('<f11>')
    assert eng.wait_signs({'cur': 'main.py:8'}) is None

    eng.feed('<c-p>')
    assert eng.wait_signs({'cur': 'main.py:16'}) is None

    eng.feed('<c-n>')
    assert eng.wait_signs({'cur': 'main.py:8'}) is None

    eng.feed('<f12>')
    assert eng.wait_signs({'cur': 'main.py:10'}) is None

    eng.feed('<f5>')
    assert eng.wait_signs({'cur': 'main.py:1'}) is None


def test_break(eng, post, terminal_end):
    '''Test toggling breakpoints.'''
    assert post
    assert terminal_end
    eng.feed(' dp')
    eng.feed('\n', 1000)
    eng.feed('<esc>')

    eng.feed('<esc><c-w>k')
    eng.feed(':5<cr>')
    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'main.py:1', 'break': {1: [5]}}) is None

    eng.exe('GdbContinue')
    assert eng.wait_signs({'cur': 'main.py:5', 'break': {1: [5]}}) is None

    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'main.py:5'}) is None


def test_navigation(eng, post, terminal_end):
    '''Test toggling breakpoints while navigating.'''
    assert post
    assert terminal_end
    eng.feed(' dp')
    eng.feed('\n', 1000)
    eng.feed('<esc>')

    eng.feed('<esc><c-w>w')
    eng.feed(':5<cr>')
    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'main.py:1', 'break': {1: [5]}}) is None

    # Go to another file
    eng.feed(':e lib.py\n')
    eng.feed(':5\n')
    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'main.py:1', 'break': {1: [5]}}) is None
    eng.feed(':7\n')
    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'main.py:1', 'break': {1: [5, 7]}}) is None

    # Return to the original file
    eng.feed(':e main.py\n')
    assert eng.wait_signs({'cur': 'main.py:1', 'break': {1: [5]}}) is None


def test_until(eng, post, terminal_end):
    '''Test run until line.'''
    assert post
    assert terminal_end
    eng.feed(' dp')
    eng.feed('\n', 1000)
    eng.feed('tbreak _main\n')
    eng.feed('cont\n')
    eng.feed('<esc>')

    eng.feed('<c-w>w')
    eng.feed(':18<cr>')
    eng.feed('<f4>')
    assert eng.wait_signs({'cur': 'main.py:18'}) is None


def test_eval(eng, post, terminal_end):
    '''Test eval <word>.'''
    assert post
    assert terminal_end
    eng.feed(' dp')
    eng.feed('\n', 1000)
    eng.feed('tbreak _main\n')
    eng.feed('cont\n')
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed('<f10>')

    eng.feed('^<f9>')
    assert eng.exec_lua('return NvimGdb.i()._last_command') == 'print(_foo)'

    eng.feed('viW')
    eng.feed(':GdbEvalRange\n')
    assert eng.exec_lua('return NvimGdb.i()._last_command') == 'print(_foo(i))'


def test_expand(eng, post):
    '''Test launch expand().'''
    assert post
    eng.feed(':e main.py\n')    # Open a file to activate %
    eng.feed(' dp')
    # Substitute main.py by % and launch
    eng.feed('<c-w><c-w><c-w>%\n', 1000)
    # Ensure a debugging session has started
    assert eng.wait_signs({'cur': 'main.py:1'}) is None
    # Clean up the main tabpage
    eng.feed('<esc>gt:new\n<c-w>ogt')


def test_repeat_last_command(eng, post, terminal_end):
    '''Ensure the last command is repeated on empty input.'''
    assert post
    assert terminal_end
    eng.feed(' dp')
    eng.feed('\n', 1000)
    eng.feed('tbreak _main\n')
    eng.feed('cont\n')

    assert eng.wait_signs({'cur': 'main.py:15'}) is None

    eng.feed('n\n')
    assert eng.wait_signs({'cur': 'main.py:16'}) is None
    eng.feed('<cr>')
    assert eng.wait_signs({'cur': 'main.py:15'}) is None
