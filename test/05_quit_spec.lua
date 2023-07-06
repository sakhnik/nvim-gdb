local thr = require'thread'
local eng = require'engine'
local conf = require'config'


local function mysetup(backend, action)
  local num_bufs = eng.count_buffers()
  eng.feed(string.format(backend.launchF, ""))
  assert.is_true(eng.wait_paused(5000))
  eng.feed("<esc>")

  action(backend)

  -- Check that no new buffers have left
  assert.are.equal(num_bufs, eng.count_buffers(), "No new rogue buffers")
  assert.are.equal(1, vim.fn.tabpagenr('$'), "No rogue tabpages")
end

describe("quit", function()
  conf.backend(function(backend)
    it(backend.name .. " using command GdbDebugStop", function()
      mysetup(backend, function()
        thr.y(0, vim.cmd("GdbDebugStop"))
      end)
    end)

    it(backend.name .. " when EOF", function()
      mysetup(backend, function()
        eng.feed("i<c-d>")
        eng.feed("<cr>")
      end)
    end)

    it(backend.name .. " when tabpage is closed", function()
      mysetup(backend, function()
        eng.feed(string.format(backend.launchF, ""))
        assert.is_true(eng.wait_paused(5000))
        eng.feed('<esc>')
        eng.feed(":tabclose<cr>")
        eng.feed(":GdbDebugStop<cr>")
      end)
    end)
  end)
end)
