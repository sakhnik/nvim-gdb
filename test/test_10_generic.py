'''Test generic operation.'''


def test_scrolloff(eng, backend, count_stops):
    '''Test that scrolloff is respected in the jump window.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None

    count_stops.reset()
    eng.feed(backend['tbreak_main'])
    assert count_stops.wait(1) is None
    eng.feed('run<cr>')
    assert count_stops.wait(2) is None
    eng.feed('<esc>')

    def _check_margin():
        jump_win = eng.exec_lua('return NvimGdb.i().win.jump_win')
        wininfo = eng.eval(f"getwininfo({jump_win})[0]")
        curline = eng.eval(f"nvim_win_get_cursor({jump_win})[0]")
        signline = int(eng.get_signs()['cur'].split(':')[1])
        assert signline == curline
        assert curline <= wininfo['botline'] - 3
        assert curline >= wininfo['topline'] + 3

    _check_margin()
    count_stops.reset()
    eng.feed('<f10>')
    assert count_stops.wait(1) is None
    _check_margin()
    eng.feed('<f11>')
    assert count_stops.wait(2) is None
    _check_margin()
