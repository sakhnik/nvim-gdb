local conf = require'conftest'
local eng = require'engine'
local thr = require'thread'
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
          thr.y(0, vim.cmd("GdbDebugStop"))
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

    it(backend.name .. ' until', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused(5000))
        eng.feed(backend.tbreak_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))
        eng.feed('<esc>')
        eng.feed('<c-w>w')
        eng.feed(':21<cr>')
        assert.is_true(eng.wait_cursor(21))
        eng.feed('<f4>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:21'}))
      end)
    end)

    it(backend.name .. ' program exit', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused(5000))
        eng.feed(backend.tbreak_main)
        eng.feed('<esc>')
        eng.feed(':Gdb run\n')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))
        eng.feed('<f5>')
        assert.is_true(eng.wait_signs({}))
      end)
    end)

    it(backend.name .. ' eval <cword>', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused(5000))
        eng.feed(backend.tbreak_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))
        eng.feed('<esc>')
        eng.feed('<c-w>w')
        assert.is_true(eng.wait_cursor(17))
        eng.feed('<f10>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:19'}))

        eng.feed('^<f9>')
        assert.equals('print Foo', NvimGdb.i()._last_command)

        eng.feed('/Lib::Baz\n')
        assert.is_true(eng.wait_cursor(21))
        eng.feed('vt(')
        eng.feed(':GdbEvalRange\n')
        assert.equals('print Lib::Baz', NvimGdb.i()._last_command)
      end)
    end)

    it(backend.name .. ' navigating to another file', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused(5000))
        eng.feed(backend.tbreak_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))
        eng.feed('<esc>')
        eng.feed('<c-w>w')
        eng.feed('/Lib::Baz\n')
        assert.is_true(eng.wait_cursor(21))
        eng.feed('<f4>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:21'}))
        eng.feed('<f11>')
        assert.is_true(eng.wait_signs({cur = 'lib.hpp:7'}))

        eng.feed('<f10>')
        assert.is_true(eng.wait_signs({cur = 'lib.hpp:8'}))
      end)
    end)

    it(backend.name .. ' repeat last command on empty input', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused(5000))
        eng.feed(backend.tbreak_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))

        eng.feed('n<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:19'}))
        eng.feed('<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))
      end)
    end)

    it(backend.name .. ' scrolloff is respected in the jump window', function()
      conf.post_terminal_end(function()
        conf.count_stops(function(count_stops)
          eng.feed(backend.launch)
          assert.is_true(eng.wait_paused(5000))
          count_stops.reset()
          eng.feed(backend.tbreak_main)
          assert.is_true(count_stops.wait(1))
          eng.feed('run<cr>')
          assert.is_true(count_stops.wait(2))
          eng.feed('<esc>')

          local function check_margin()
            local jump_win = NvimGdb.i().win.jump_win
            local wininfo = vim.fn.getwininfo(jump_win)[1]
            local curline = vim.api.nvim_win_get_cursor(jump_win)[1]
            local signline = tonumber(vim.split(eng.get_signs().cur, ':')[2])
            assert.equals(signline, curline)
            local botline = wininfo.botline - 3
            assert.is_true(curline <= botline, string.format("curline=%d <= botline=%d", curline, botline))
            local topline = wininfo.topline + 3
            assert.is_true(curline >= topline, string.format("curline=%d >= topline=%d", curline, topline))
          end

          check_margin()
          count_stops.reset()
          eng.feed('<f10>')
          assert.is_true(count_stops.wait(1))
          check_margin()
          eng.feed('<f11>')
          assert.is_true(count_stops.wait(2))
          check_margin()
        end)
      end)
    end)

  end)
end)
