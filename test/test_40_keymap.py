import pytest


def launch(eng):
    eng.feed(":GdbStart ./dummy-gdb.sh\n")

@pytest.fixture(scope='function')
def keymap(eng, post):
    yield
    eng.exe('source keymap_cleanup.vim')

def test_hooks(eng, keymap):
    # Test custom programmable keymaps.
    eng.exe("source keymap_hooks.vim")
    launch(eng)

    assert 0 == eng.eval('g:test_tkeymap')
    eng.feed('~tkm')
    assert 1 == eng.eval('g:test_tkeymap')
    eng.feed('<esc>')
    assert 0 == eng.eval('g:test_keymap')
    eng.feed('~tn')
    assert 1 == eng.eval('g:test_keymap')
    eng.exe('let g:test_tkeymap = 0 | let g:test_keymap = 0')
    eng.feed('<c-w>w')
    assert 0 == eng.eval('g:test_keymap')
    eng.feed('~tn')
    assert 1 == eng.eval('g:test_keymap')
    eng.exe('let g:test_keymap = 0')

def test_conflict(eng, keymap):
    eng.exe("let g:nvimgdb_config = {'key_next': '<f5>', 'key_prev': '<f5>'}")
    launch(eng)

    count = eng.eval('len(filter(GdbTestPeekConfig(), {k,v -> k =~ "^key_.*"}))')
    assert 1 == count
    # Check that the cursor is moving freely without stucking
    eng.feed('<c-\\><c-n>')
    eng.feed('<c-w>w')
    eng.feed('<c-w>w')

def test_override(eng, keymap):
    eng.exe("let g:nvimgdb_config_override = {'key_next': '<f2>'}")
    launch(eng)
    key = eng.eval('get(GdbTestPeekConfig(), "key_next", 0)')
    assert '<f2>' == key

def test_override_priority(eng, keymap):
    # Check that a config override assumes priority in a conflict
    eng.exe("let g:nvimgdb_config_override = {'key_next': '<f8>'}")
    launch(eng)
    res = eng.eval('get(GdbTestPeekConfig(), "key_breakpoint", 0)')
    assert 0 == res

def test_override_one(eng, keymap):
    eng.exe("let g:nvimgdb_key_next = '<f3>'")
    launch(eng)
    key = eng.eval('get(GdbTestPeekConfig(), "key_next", 0)')
    assert '<f3>' == key

def test_override_one_priority(eng, keymap):
    eng.exe("let g:nvimgdb_key_next = '<f8>'")
    launch(eng)
    res = eng.eval('get(GdbTestPeekConfig(), "key_breakpoint", 0)')
    assert 0 == res

def test_overall(eng, keymap):
    eng.exe("let g:nvimgdb_config_override = {'key_next': '<f5>'}")
    eng.exe("let g:nvimgdb_key_step = '<f5>'")
    launch(eng)
    res = eng.eval('get(GdbTestPeekConfig(), "key_continue", 0)')
    assert 0 == res
    res = eng.eval('get(GdbTestPeekConfig(), "key_next", 0)')
    assert 0 == res
    key = eng.eval('get(GdbTestPeekConfig(), "key_step", 0)')
    assert '<f5>' == key
