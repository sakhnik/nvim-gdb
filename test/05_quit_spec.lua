local thr = require'thread'

local function feed(keys)
  vim.api.nvim_input(keys)
  thr.y(200)
end

local count_buffers = function()
  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      count = count + 1
    end
  end
  return count
end


describe("my_module", function()
  local num_bufs = nil

  before_each(function()
    num_bufs = count_buffers()
    feed(" dd a.out<cr>")
    thr.y(500)
    feed("<esc>")
  end)

  after_each(function()
    -- Check that no new buffers have left
    assert.are.equal(num_bufs, count_buffers())
    assert.are.equal(1, vim.fn.tabpagenr('$'))
  end)

  describe("quit", function()
    it("using command GdbDebugStop", function()
      thr.y(0, vim.cmd("GdbDebugStop"))
      -- Check that no new buffers have left
      assert.are.equal(num_bufs, count_buffers())
      assert.are.equal(1, vim.fn.tabpagenr('$'))
    end)
    it("when EOF", function()
      feed("i<c-d>")
      feed("<cr>")
      assert.are.equal(num_bufs, count_buffers())
      assert.are.equal(1, vim.fn.tabpagenr('$'))
    end)
    it("when tabpage is closed", function()
      feed(":GdbStart gdb -q<cr>")
      thr.y(500)
      feed('<esc>')
      feed(":tabclose<cr>")
      feed(":GdbDebugStop<cr>")
      assert.are.equal(num_bufs, count_buffers())
      assert.are.equal(1, vim.fn.tabpagenr('$'))
    end)
  end)

  --describe("subtract", function()
  --  it("should return the difference between two numbers", function()
  --    assert.are.equal(3, 3)
  --  end)
  --end)
end)
