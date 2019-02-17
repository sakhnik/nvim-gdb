

tests = {
    'gdb': [("GdbCustomCommand('print i')", '$1 = 0'),
            ("GdbCustomCommand('info locals')", 'i = 0')],
    'lldb': [("GdbCustomCommand('frame var argc')", "(int) argc = 1"),
             ("GdbCustomCommand('frame var i')", "(int) i = 0")],
}

def test_backend(eng, backend):
    eng.feed(backend['launch'])
    assert eng.waitPaused(1000) is None
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<f10>')
    for cmd, exp in tests[backend['name']]:
        assert exp == eng.eval(cmd)

def test_pdb(eng, post):
    eng.feed(' dp')
    eng.feed('\n', 300)
    eng.feed('b _Foo\n')
    eng.feed('cont\n')
    assert "0" == eng.eval("GdbCustomCommand('print(n)')")
    eng.feed('cont\n')
    assert "1" == eng.eval("GdbCustomCommand('print(n)')")
