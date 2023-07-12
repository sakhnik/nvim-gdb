local conf = require'conftest'
local eng = require'engine'
local utils = require'nvimgdb.utils'


describe("generic", function()
  conf.backend(function(backend)
    it(backend.name .. ' smoke', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused(5000))
        eng.feed(backend.tbreak_main)
        eng.feed('run<cr>')
        eng.feed('<esc>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))

        eng.feed('<f10>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:19'}))

        eng.feed('<f11>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:10'}))

        eng.feed('<c-p>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:19'}))

        eng.feed('<c-n>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:10'}))

        eng.feed('<f12>')

        local function check_signs(signs)
          -- different for different compilers
          return vim.deep_equal(signs, {cur = 'test.cpp:17'}) or vim.deep_equal(signs, {cur = 'test.cpp:19'})
        end
        assert.is_true(eng.wait_for(eng.get_signs, check_signs))

        eng.feed('<f5>')
        assert.is_true(eng.wait_signs({}))
      end)
    end)

    it(backend.name .. ' breaks', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused(5000))
        eng.feed('<esc><c-w>w')
        eng.feed(":e src/test.cpp\n")
        eng.feed(':5<cr>')
        eng.feed('<f8>')
        assert.is_true(eng.wait_signs({brk = {[1] = {5}}}))

        eng.exe("GdbRun")
        assert.is_true(eng.wait_signs({cur = 'test.cpp:5', brk = {[1] = {5}}}))

        eng.feed('<f8>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:5'}))
      end)
    end)

    it(backend.name .. ' interrupt', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused(5000))
        if utils.is_windows and backend.name == 'lldb' then
          pending("LLDB shows prompt even while the target is running")
        end
        eng.feed('run 4294967295<cr>')
        eng.feed('<esc>')
        assert.is_false(eng.wait_paused(1000))
        eng.feed(':GdbInterrupt\n')
        if not utils.is_windows then
          assert.is_true(eng.wait_signs({cur = 'test.cpp:22'}))
        else
          -- Most likely to break in the kernel code
        end
        assert.is_true(eng.wait_paused(1000))
      end)
    end)

--def test_until(eng, backend):
--    '''Test run until.'''
--    eng.feed(backend['launch'])
--    assert eng.wait_paused() is None
--    eng.feed(backend['tbreak_main'])
--    eng.feed('run<cr>', 1000)
--    eng.feed('<esc><esc><esc>')
--    eng.feed('<c-w>w', 300)
--    eng.feed(':21<cr>')
--    eng.feed('<f4>')
--    assert eng.wait_signs({'cur': 'test.cpp:21'}) is None
--
--
--def test_program_exit(eng, backend):
--    '''Test the cursor is hidden after program end.'''
--    eng.feed(backend['launch'])
--    assert eng.wait_paused() is None
--    eng.feed(backend['tbreak_main'])
--    eng.feed('<esc>')
--    eng.feed(':Gdb run\n', 1000)
--    eng.feed('<f5>')
--    assert eng.wait_signs({}) is None
--
--
--def test_eval(eng, backend):
--    '''Test eval <cword>.'''
--    eng.feed(backend['launch'])
--    assert eng.wait_paused() is None
--    eng.feed(backend['tbreak_main'])
--    eng.feed('run<cr>', 1000)
--    eng.feed('<esc>')
--    eng.feed('<c-w>w')
--    eng.feed('<f10>')
--
--    eng.feed('^<f9>')
--    assert eng.exec_lua('return NvimGdb.i()._last_command') == 'print Foo'
--
--    eng.feed('/Lib::Baz\n')
--    eng.feed('vt(')
--    eng.feed(':GdbEvalRange\n')
--    assert eng.exec_lua('return NvimGdb.i()._last_command') == 'print Lib::Baz'
--
--
--def test_navigate(eng, backend):
--    '''Test navigating to another file.'''
--    eng.feed(backend['launch'])
--    assert eng.wait_paused() is None
--    eng.feed(backend['tbreak_main'])
--    eng.feed('run<cr>', 1000)
--    eng.feed('<esc>')
--    eng.feed('<c-w>w')
--    eng.feed('/Lib::Baz\n', 300)
--    eng.feed('<f4>')
--    eng.feed('<f11>')
--    assert eng.wait_signs({'cur': 'lib.hpp:7'}) is None
--
--    eng.feed('<f10>')
--    assert eng.wait_signs({'cur': 'lib.hpp:8'}) is None
--
--
--def test_repeat_last_command(eng, backend):
--    '''Last command is repeated on empty input.'''
--    eng.feed(backend['launch'])
--    assert eng.wait_paused() is None
--    eng.feed(backend['tbreak_main'])
--    eng.feed('run<cr>')
--    assert eng.wait_signs({'cur': 'test.cpp:17'}) is None
--
--    eng.feed('n<cr>')
--    assert eng.wait_signs({'cur': 'test.cpp:19'}) is None
--    eng.feed('<cr>')
--    assert eng.wait_signs({'cur': 'test.cpp:17'}) is None
--
--
--def test_scrolloff(eng, backend, count_stops):
--    '''Test that scrolloff is respected in the jump window.'''
--    eng.feed(backend['launch'])
--    assert eng.wait_paused() is None
--
--    count_stops.reset()
--    eng.feed(backend['tbreak_main'])
--    assert count_stops.wait(1) is None
--    eng.feed('run<cr>')
--    assert count_stops.wait(2) is None
--    eng.feed('<esc>')
--
--    def _check_margin():
--        jump_win = eng.exec_lua('return NvimGdb.i().win.jump_win')
--        wininfo = eng.eval(f"getwininfo({jump_win})[0]")
--        curline = eng.eval(f"nvim_win_get_cursor({jump_win})[0]")
--        signline = int(eng.get_signs()['cur'].split(':')[1])
--        assert signline == curline
--        assert curline <= wininfo['botline'] - 3
--        assert curline >= wininfo['topline'] + 3
--
--    _check_margin()
--    count_stops.reset()
--    eng.feed('<f10>')
--    assert count_stops.wait(1) is None
--    _check_margin()
--    eng.feed('<f11>')
--    assert count_stops.wait(2) is None
--    _check_margin()
  end)
end)
