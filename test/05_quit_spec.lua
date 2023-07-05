local thr = require'thread'
local eng = require'engine'


describe("quit", function()
  local num_bufs = nil

  before_each(function()
    num_bufs = eng.count_buffers()
    eng.feed(" dd a.out<cr>")
    assert.is_true(eng.wait_paused(5000))
    eng.feed("<esc>")
  end)

  it("using command GdbDebugStop", function()
    thr.y(0, vim.cmd("GdbDebugStop"))
    -- Check that no new buffers have left
    assert.are.equal(num_bufs, eng.count_buffers())
    assert.are.equal(1, vim.fn.tabpagenr('$'))
  end)

  it("when EOF", function()
    eng.feed("i<c-d>")
    eng.feed("<cr>")
    assert.are.equal(num_bufs, eng.count_buffers())
    assert.are.equal(1, vim.fn.tabpagenr('$'))
  end)

  it("when tabpage is closed", function()
    eng.feed(":GdbStart gdb -q<cr>")
    assert.is_true(eng.wait_paused(5000))
    eng.feed('<esc>')
    eng.feed(":tabclose<cr>")
    eng.feed(":GdbDebugStop<cr>")
    -- TODO: why new buffer?
    assert.are.equal(num_bufs + 1, eng.count_buffers())
    assert.are.equal(1, vim.fn.tabpagenr('$'))
  end)
end)
