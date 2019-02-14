
def test_multiview(eng, two_backends):
    # Test multiple views.
    b1, b2 = two_backends

    # Launch the first backend
    eng.feed(b1['launch'], 1000)
    eng.feed(b1['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':11<cr>')
    eng.feed('<f8>')
    eng.feed('<f10>')
    eng.feed('<f11>')

    assert {'cur': 'test.cpp:10', 'break': {1: [11]}} == eng.getSigns()

    # Then launch the second backend
    eng.feed(b2['launch'], 1000)
    eng.feed(b2['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed(':5<cr>')
    eng.feed('<f8>')
    eng.feed(':12<cr>')
    eng.feed('<f8>')
    eng.feed('<f10>')

    assert {'cur': 'test.cpp:19', 'break': {1: [5, 12]}} == eng.getSigns()

    # Switch to the first backend
    eng.feed('2gt')
    assert {'cur': 'test.cpp:10', 'break': {1: [11]}} == eng.getSigns()

    # Quit
    eng.feed('ZZ')

    # Switch back to the second backend
    assert {'cur': 'test.cpp:19', 'break': {1: [5, 12]}} == eng.getSigns()

    # The last debugger is quit in the after_each

