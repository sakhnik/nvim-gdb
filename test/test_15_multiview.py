'''Test multiple debugging sessions at once.'''


def test_multiview(eng, two_backends):
    '''Test multiple views.'''
    back1, back2 = two_backends

    # Launch the first backend
    eng.feed(back1['launch'])
    assert eng.wait_paused() is None
    eng.feed(back1['tbreak_main'])
    eng.feed('run<cr>', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':11<cr>')
    eng.feed('<f8>')
    eng.feed('<f10>')
    eng.feed('<f11>')

    assert eng.wait_signs({'cur': 'test.cpp:10', 'break': {1: [11]}}) is None

    # Then launch the second backend
    eng.feed(back2['launch'])
    assert eng.wait_paused() is None
    eng.feed(back2['tbreak_main'])
    eng.feed('run<cr>', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':5<cr>')
    eng.feed('<f8>')
    eng.feed(':12<cr>')
    eng.feed('<f8>')
    eng.feed('<f10>')

    assert eng.wait_signs({'cur': 'test.cpp:19', 'break': {1: [5, 12]}}) is None

    # Switch to the first backend
    eng.feed('1gt')
    assert eng.wait_signs({'cur': 'test.cpp:10', 'break': {1: [11]}}) is None

    # Quit
    eng.feed(':GdbDebugStop<cr>')

    # Switch back to the second backend
    eng.feed('2gt')
    assert eng.wait_signs({'cur': 'test.cpp:19', 'break': {1: [5, 12]}}) is None

    # The last debugger is quit automatically
