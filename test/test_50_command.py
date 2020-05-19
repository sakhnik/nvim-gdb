'''Test custom command.'''

import time


TESTS = {
    'gdb': [("GdbCustomCommand('print i')", '$1 = 0'),
            ("GdbCustomCommand('info locals')", 'i = 0')],
    'lldb': [("GdbCustomCommand('frame var argc')", "(int) argc = 1"),
             ("GdbCustomCommand('frame var i')", "(int) i = 0")],
}


def test_backend(eng, backend):
    '''Custom command in C++.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    eng.feed('<f10>')
    for cmd, exp in TESTS[backend['name']]:
        assert exp == eng.eval(cmd)

def test_pdb(eng, post):
    '''Custom command in PDB.'''
    assert post
    eng.feed(' dp')
    eng.feed('\n', 300)
    eng.feed('b _foo\n')
    eng.feed('cont\n')
    assert eng.eval("GdbCustomCommand('print(num)')") == "0"
    eng.feed('cont\n')
    assert eng.eval("GdbCustomCommand('print(num)')") == "1"

WATCH_TESTS = {
    'gdb': ('info locals', ['i = 0']),
    'lldb': ('frame var i', ['(int) i = 0']),
}

def test_watch_backend(eng, backend):
    '''Watch window with custom command in C++.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['tbreak_main'])
    eng.feed('run\n', 1000)
    eng.feed('<esc>')
    cmd, res = WATCH_TESTS[backend["name"]]
    eng.feed(f':GdbCreateWatch {cmd}\n')
    eng.feed(':GdbNext\n')
    out = eng.eval(f"getbufline('{cmd}', 1)")
    assert out == res
    time.sleep(1)
