local conf = require'conftest'
local eng = require'engine'
local utils = require'nvimgdb.utils'

local uv = vim.loop

describe("breakpoint", function()
  conf.backend(function(backend)

    it(backend.name .. ' manual breakpoint is detected', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused())
        eng.feed(backend.break_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17', brk = {[1] = {17}}}))
      end)
    end)

    ---Fixture to change directory temporarily.
    local function cd_tmp(action)
      local old_dir = uv.fs_realpath('.')
      local tmp_dir = uv.fs_mkdtemp(uv.os_tmpdir() .. '/nvimgdb-test-XXXXXX')
      vim.loop.chdir(tmp_dir)
      action(utils.path_join(old_dir, conf.aout))
      uv.chdir(old_dir)
      uv.fs_rmdir(tmp_dir)
    end

    it(backend.name .. ' manual breakpoint is detected from a random directory', function()
      conf.post_terminal_end(function()
        cd_tmp(function(aout_path)
          eng.feed(string.format(backend.launchF, aout_path))
          assert.is_true(eng.wait_paused())
          eng.feed(backend.break_main)
          eng.feed('run<cr>')
          assert.is_true(eng.wait_signs({cur = 'test.cpp:17', brk = {[1] = {17}}}))
        end)
      end)
    end)

    it(backend.name .. ' breakpoints stay when source code is navigated', function()
      -- Verify that breakpoints stay when source code is navigated.
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused())
        eng.feed(backend.break_bar)
        eng.feed("<esc>:wincmd w<cr>")
        eng.feed(":e src/test.cpp\n")
        eng.feed(":10<cr>")
        eng.feed("<f8>")

        assert.is_true(eng.wait_signs({brk = {[1] = {5, 10}}}))

        -- Go to another file
        eng.feed(":e src/lib.hpp\n")
        assert.is.same({}, eng.get_signs())
        eng.feed(":8\n")
        eng.feed("<f8>")
        assert.is_true(eng.wait_signs({brk = {[1] = {8}}}))

        -- Return to the first file
        eng.feed(":e src/test.cpp\n")
        assert.is_true(eng.wait_signs({brk = {[1] = {5, 10}}}))
      end)
    end)

    it(backend.name .. ' can clear all breakpoints', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused())
        eng.feed(backend.break_bar)
        eng.feed(backend.break_main)
        eng.feed("<esc>:wincmd w<cr>")
        eng.feed(":e src/test.cpp\n")
        eng.feed(":10<cr>")
        eng.feed("<f8>")

        assert.is_true(eng.wait_signs({brk = {[1] = {5, 10, 17}}}))

        eng.feed(":GdbBreakpointClearAll\n")
        assert.is_true(eng.wait_signs({}))
      end)
    end)

    it(backend.name .. ' duplicate breakpoints are displayed distinctively', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused())
        eng.feed(backend.break_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17', brk = {[1] = {17}}}))
        eng.feed(backend.break_main)
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17', brk = {[2] = {17}}}))
        eng.feed(backend.break_main)
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17', brk = {[3] = {17}}}))
        eng.feed("<esc>:wincmd w<cr>")
        eng.feed(":17<cr>")
        eng.feed("<f8>")
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17', brk = {[2] = {17}}}))
        eng.feed("<f8>")
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17', brk = {[1] = {17}}}))
        eng.feed("<f8>")
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))
      end)
    end)

    it(backend.name .. ' watchpoint transitions to paused', function()
      conf.post_terminal_end(function()
        if vim.env.GITHUB_WORKFLOW ~= nil and backend.name == 'lldb' then
          pending("Known to fail in GitHub actions")
        end
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused())
        eng.feed(backend.break_main)
        eng.feed('run<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17', brk = {[1] = {17}}}))
        eng.feed(backend.watchF:format('i'))
        eng.feed('cont<cr>')
        assert.is_true(eng.wait_paused())
        assert.is_true(eng.wait_signs({cur = 'test.cpp:17', brk = {[1] = {17}}}))
      end)
    end)

  end)
end)
