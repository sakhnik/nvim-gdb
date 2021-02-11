'''Test keymaps configuration.'''

# pylint: disable=redefined-outer-name

import pytest


@pytest.fixture(scope='function')
def keymap(eng, post):
    '''Fixture to clear custom keymaps.'''
    assert post
    yield True
    eng.exe('source keymap_cleanup.vim')


def test_hooks(eng, keymap):
    '''Test custom programmable keymaps.'''
    assert keymap
    eng.exe("source keymap_hooks.vim")
    eng.feed(":GdbStart ./dummy-gdb.sh\n")

    assert eng.eval('g:test_tkeymap') == 0
    eng.feed('~tkm')
    assert eng.eval('g:test_tkeymap') == 1
    eng.feed('<esc>')
    assert eng.eval('g:test_keymap') == 0
    eng.feed('~tn')
    assert eng.eval('g:test_keymap') == 1
    eng.exe('let g:test_tkeymap = 0 | let g:test_keymap = 0')
    eng.feed('<c-w>w')
    assert eng.eval('g:test_keymap') == 0
    eng.feed('~tn')
    assert eng.eval('g:test_keymap') == 1
    eng.exe('let g:test_keymap = 0')


def test_conflict(eng, keymap):
    '''Conflicting keymap.'''
    assert keymap
    eng.exe("let g:nvimgdb_config = {'key_next': '<f5>', 'key_prev': '<f5>'}")
    eng.feed(":GdbStart ./dummy-gdb.sh\n")

    count = eng.exec_lua("""
        return (function()
            count = 0
            for key, _ in pairs(NvimGdb.i().config.config) do
                if key:match("^key_.*") ~= nil then
                    count = count + 1
                end
            end
            return count
        end)()""")
    assert count == 1
    # Check that the cursor is moving freely without stucking
    eng.feed('<c-\\><c-n>')
    eng.feed('<c-w>w')
    eng.feed('<c-w>w')


def test_override(eng, keymap):
    '''Override a key.'''
    assert keymap
    eng.exe("let g:nvimgdb_config_override = {'key_next': '<f2>'}")
    eng.feed(":GdbStart ./dummy-gdb.sh\n")
    key = eng.exec_lua('return NvimGdb.i().config:get("key_next")')
    assert key == '<f2>'


def test_override_priority(eng, keymap):
    '''Check that a config override assumes priority in a conflict.'''
    assert keymap
    eng.exe("let g:nvimgdb_config_override = {'key_next': '<f8>'}")
    eng.feed(":GdbStart ./dummy-gdb.sh\n")
    res = eng.exec_lua('return NvimGdb.i().config:get_or("key_breakpoint", 0)')
    assert res == 0


def test_override_one(eng, keymap):
    '''Override a single key.'''
    assert keymap
    eng.exe("let g:nvimgdb_key_next = '<f3>'")
    eng.feed(":GdbStart ./dummy-gdb.sh\n")
    key = eng.exec_lua('return NvimGdb.i().config:get_or("key_next", 0)')
    assert key == '<f3>'


def test_override_one_priority(eng, keymap):
    '''Override a single key, priority.'''
    assert keymap
    eng.exe("let g:nvimgdb_key_next = '<f8>'")
    eng.feed(":GdbStart ./dummy-gdb.sh\n")
    res = eng.exec_lua('return NvimGdb.i().config:get_or("key_breakpoint", 0)')
    assert res == 0


def test_overall(eng, keymap):
    '''Smoke test.'''
    assert keymap
    eng.exe("let g:nvimgdb_config_override = {'key_next': '<f5>'}")
    eng.exe("let g:nvimgdb_key_step = '<f5>'")
    eng.feed(":GdbStart ./dummy-gdb.sh\n")
    res = eng.exec_lua('return NvimGdb.i().config:get_or("key_continue", 0)')
    assert res == 0
    res = eng.exec_lua('return NvimGdb.i().config:get_or("key_next", 0)')
    assert res == 0
    key = eng.exec_lua('return NvimGdb.i().config:get_or("key_step", 0)')
    assert key == '<f5>'
