local conf = require'conftest'
local eng = require'engine'
local thr = require'thread'
local utils = require'nvimgdb.utils'

describe("command", function()

  local tests = {
      gdb = {{"GdbCustomCommand('print i')", '$1 = 0'},
              {"GdbCustomCommand('info locals')", 'i = 0'}},
      lldb = {{"GdbCustomCommand('frame var argc')", "(int) argc = 1"},
               {"GdbCustomCommand('frame var i')", "(int) i = 0"}},
  }

  conf.backend(function(backend)
    it(backend.name .. ' custom command in C++', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused())
        eng.feed(backend.tbreak_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))
        eng.feed('<esc>')
        eng.feed('<f10>')
        if utils.is_windows and backend.name == 'lldb' then
          thr.y(300)
        end
        for _, test in ipairs(tests[backend.name]) do
          local cmd, exp = unpack(test)
          assert.equals(exp, vim.fn.eval(cmd))
        end
      end)
    end)
  end)

  it('custom command in PDB', function()
    conf.post_terminal_end(function()
      conf.count_stops(function(count_stops)
        eng.feed(' dp<cr>')
        assert.is_true(count_stops.wait(1))
        eng.feed('b _foo<cr>')
        assert.is_true(count_stops.wait(2))
        eng.feed('cont<cr>')

        local function print_num()
          return vim.fn.GdbCustomCommand('print(num)')
        end

        assert.is_true(eng.wait_for(print_num, function(res) return res == "0" end))
        eng.feed('cont<cr>')
        assert.is_true(eng.wait_for(print_num, function(res) return res == "1" end))
      end)
    end)
  end)

  local watch_tests = {
      gdb = {'info locals', {'i = 0'}},
      lldb = {'frame var i', {'(int) i = 0'}},
  }

  conf.backend(function(backend)

    it(backend.name .. ' watch window with custom command in C++', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused())
        eng.feed(backend.tbreak_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_paused())
        eng.feed('<esc>')
        local cmd, res = unpack(watch_tests[backend.name])
        eng.feed(':GdbCreateWatch ' .. cmd .. '\n')
        eng.feed(':GdbNext\n')
        local function query()
          return vim.fn.getbufline(cmd, 1)
        end
        assert.is_true(eng.wait_for(query, function(out) return vim.deep_equal(out, res) end))
      end)
    end)

    it(backend.name .. ' cleanup of watch window with custom command in C++', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused())
        eng.feed(backend.tbreak_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_paused())
        eng.feed('<esc>')
        local cmd, res = unpack(watch_tests[backend.name])
        eng.feed(':GdbCreateWatch ' .. cmd .. '\n')
        local bufname = cmd:gsub(" ", "\\ ")
        -- If a user wants to get rid of the watch window manually,
        -- the plugin should take care of properly getting rid of autocommands
        -- in the backend.
        local auid = vim.api.nvim_create_autocmd('User', {pattern='NvimGdbCleanup', command='bwipeout! ' .. bufname})

        eng.feed(':GdbDebugStop\n')

        -- Start and test another time to check that no error is raised
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused())
        eng.feed(backend.tbreak_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_paused())
        eng.feed('<esc>')
        eng.feed(':GdbCreateWatch ' .. cmd .. '\n')
        eng.feed(':GdbNext\n')
        local function query()
          return vim.fn.getbufline(cmd, 1)
        end
        assert.is_true(eng.wait_for(query, function(out) return vim.deep_equal(out, res) end))

        vim.api.nvim_del_autocmd(auid)
      end)
    end)

  end)

end)