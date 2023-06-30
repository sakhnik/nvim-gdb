'''Test window layout.'''


def test_term_above(eng, post, terminal_end, config_test):
    '''Test terminal window above.'''
    assert config_test
    eng.exe('let w:nvimgdb_termwin_command = "aboveleft new"')
    eng.exe('e config.py')
    eng.feed(' dp')
    eng.feed('<cr>', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>j')
    assert 'main.py' == eng.eval('expand("%:t")')


def test_term_right(eng, post, terminal_end, config_test):
    '''Test terminal window to the right.'''
    assert config_test
    eng.exe('let w:nvimgdb_termwin_command = "belowright vnew"')
    eng.exe('e config.py')
    eng.feed(' dp')
    eng.feed('<cr>', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>h')
    assert 'main.py' == eng.eval('expand("%:t")')


def test_term_inplace_bottom(eng, post, terminal_end, config_test):
    '''Test terminal window in the current window below the jump window.'''
    assert config_test
    eng.exe('let w:nvimgdb_termwin_command = ""')
    eng.exe('e config.py')
    eng.feed(' dp')
    eng.feed('<cr>', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>k')
    assert 'main.py' == eng.eval('expand("%:t")')


def test_term_inplace_above(eng, post, terminal_end, config_test):
    '''Test terminal window in the current window below the jump window.'''
    assert config_test
    eng.exe('let w:nvimgdb_termwin_command = ""')
    eng.exe('let t:nvimgdb_codewin_command = "belowright new"')
    eng.exe('e config.py')
    eng.feed(' dp')
    eng.feed('<cr>', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>j')
    assert 'main.py' == eng.eval('expand("%:t")')


def test_term_inplace_right(eng, post, terminal_end, config_test):
    '''Test terminal window in the current window left of the jump window.'''
    assert config_test
    eng.exe('let w:nvimgdb_termwin_command = ""')
    eng.exe('let t:nvimgdb_codewin_command = "rightbelow vnew"')
    eng.exe('e config.py')
    eng.feed(' dp')
    eng.feed('<cr>', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>l')
    assert 'main.py' == eng.eval('expand("%:t")')
