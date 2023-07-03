'''Test keymaps configuration.'''

# pylint: disable=redefined-outer-name


def test_hooks(eng, config_test, backend_express):
    '''Test custom programmable keymaps.'''
    assert config_test
    eng.exe("source keymap_hooks.vim")
    eng.feed(backend_express['launchF'].format(""))

    def _get_var(var):
        return lambda: eng.eval(var)

    def _is_one(val):
        return val == 1

    assert eng.eval('g:test_tkeymap') == 0
    eng.feed('~tkm')
    assert eng.wait_for(_get_var('g:test_tkeymap'), _is_one) is None
    eng.feed('<esc>')
    assert eng.eval('g:test_keymap') == 0
    eng.feed('~tn')
    assert eng.wait_for(_get_var('g:test_keymap'), _is_one) is None
    eng.exe('let g:test_tkeymap = 0 | let g:test_keymap = 0')
    eng.feed('<c-w>w')
    assert eng.eval('g:test_keymap') == 0
    eng.feed('~tn')
    assert eng.wait_for(_get_var('g:test_keymap'), _is_one) is None
    eng.exe('let g:test_keymap = 0')


def test_conflict(eng, config_test, backend_express):
    '''Conflicting keymap.'''
    assert config_test
    eng.exe("let g:nvimgdb_config = {'key_next': '<f5>', 'key_prev': '<f5>'}")
    eng.feed(backend_express['launchF'].format(""))

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


def test_override(eng, config_test, backend_express):
    '''Override a key.'''
    assert config_test
    eng.exe("let g:nvimgdb_config_override = {'key_next': '<f2>'}")
    eng.feed(backend_express['launchF'].format(""))
    key = eng.exec_lua('return NvimGdb.i().config:get("key_next")')
    assert key == '<f2>'


def test_override_priority(eng, config_test, backend_express):
    '''Check that a config override assumes priority in a conflict.'''
    assert config_test
    eng.exe("let g:nvimgdb_config_override = {'key_next': '<f8>'}")
    eng.feed(backend_express['launchF'].format(""))
    res = eng.exec_lua('return NvimGdb.i().config:get_or("key_breakpoint", 0)')
    assert res == 0


def test_override_one(eng, config_test, backend_express):
    '''Override a single key.'''
    assert config_test
    eng.exe("let g:nvimgdb_key_next = '<f3>'")
    eng.feed(backend_express['launchF'].format(""))
    key = eng.exec_lua('return NvimGdb.i().config:get_or("key_next", 0)')
    assert key == '<f3>'


def test_override_one_priority(eng, config_test, backend_express):
    '''Override a single key, priority.'''
    assert config_test
    eng.exe("let g:nvimgdb_key_next = '<f8>'")
    eng.feed(backend_express['launchF'].format(""))
    res = eng.exec_lua('return NvimGdb.i().config:get_or("key_breakpoint", 0)')
    assert res == 0


def test_overall(eng, config_test, backend_express):
    '''Smoke test.'''
    assert config_test
    eng.exe("let g:nvimgdb_config_override = {'key_next': '<f5>'}")
    eng.exe("let g:nvimgdb_key_step = '<f5>'")
    eng.feed(backend_express['launchF'].format(""))
    res = eng.exec_lua('return NvimGdb.i().config:get_or("key_continue", 0)')
    assert res == 0
    res = eng.exec_lua('return NvimGdb.i().config:get_or("key_next", 0)')
    assert res == 0
    key = eng.exec_lua('return NvimGdb.i().config:get_or("key_step", 0)')
    assert key == '<f5>'
