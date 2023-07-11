local thr = require'thread'
local eng = require'engine'
local conf = require'conftest'
local utils = require'nvimgdb.utils'


local function mysetup(backend, action)
  eng.feed(string.format(backend.launchF, ""))
  assert.is_true(eng.wait_paused(5000))
  if utils.is_windows and backend.name == 'lldb' then
    thr.y(500)
  end
  eng.feed("<esc>")

  action(backend)

  assert.are.equal(1, vim.fn.tabpagenr('$'), "No rogue tabpages")
end

local function mysetup_bufcheck(backend, action)
  local num_bufs = eng.count_buffers()

  mysetup(backend, action)

  assert.are.equal(num_bufs, eng.count_buffers(), "No new rogue buffers")
end

describe("quit", function()
  conf.backend(function(backend)
    it(backend.name .. " using command GdbDebugStop", function()
      mysetup_bufcheck(backend, function()
        eng.exe("GdbDebugStop")
      end)
    end)

    it(backend.name .. " when EOF", function()
      mysetup_bufcheck(backend, function()
        if utils.is_windows and backend.name == 'lldb' then
          -- lldb doesn't like ^D in Windows
          eng.feed("iquit<cr>")
        else
          eng.feed("i<c-d>")
        end
        eng.feed("<cr>")
      end)
    end)

    it(backend.name .. " terminal can be closed", function()
      -- Disable terminal stickiness.
      vim.g.nvimgdb_sticky_dbg_buf = false
      mysetup_bufcheck(backend, function()
        -- GDB terminal can be closed.
        assert.equal(2, #vim.api.nvim_list_wins())
        eng.feed(":q<cr>")
        assert.equal(1, #vim.api.nvim_list_wins())
        eng.feed(":GdbDebugStop<cr>")
      end)
      vim.g.nvimgdb_sticky_dbg_buf = nil
    end)

    it(backend.name .. " when tabpage is closed", function()
      mysetup(backend, function()
        eng.feed(string.format(backend.launchF, ""))
        if utils.is_windows and backend.name == 'lldb' then
          thr.y(500)
        end
        assert.is_true(eng.wait_paused(5000))
        eng.feed('<esc>')
        eng.feed(":tabclose<cr>")
        eng.feed(":GdbDebugStop<cr>")
      end)
    end)
  end)
end)
