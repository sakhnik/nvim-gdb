local conf = require'conftest'
local eng = require'engine'


describe("generic", function()

  local backends = {}
  if conf.backends.gdb ~= nil then
    table.insert(backends, conf.backends.gdb)
  end
  if conf.backends.lldb ~= nil then
    table.insert(backends, conf.backends.lldb)
  end
  if #backends < 2 then
    table.insert(backends, backends[1])
  end
  if #backends == 0 then
    pending("No usable C++ debugger backends")
  end

  it('multiple views ' .. backends[1].name .. "+" .. backends[2].name, function()
    conf.post_terminal_end(function()
      local back1, back2 = unpack(backends)

      -- Launch the first backend
      eng.feed(back1.launch)
      assert.is_true(eng.wait_paused())
      eng.feed(back1.tbreak_main)
      eng.feed('run<cr>')
      assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))
      eng.feed('<esc>')
      eng.feed('<c-w>w')
      eng.feed(':11<cr>')
      assert.is_true(eng.wait_cursor(11))
      eng.feed('<f8>')
      eng.feed('<f10>')
      eng.feed('<f11>')

      assert.is_true(eng.wait_signs({cur = 'test.cpp:10', brk = {[1] = {11}}}))

      -- Then launch the second backend
      eng.feed(back2.launch)
      assert.is_true(eng.wait_paused())
      eng.feed(back2.tbreak_main)
      eng.feed('run<cr>')
      assert.is_true(eng.wait_signs({cur = 'test.cpp:17'}))
      eng.feed('<esc>')
      eng.feed('<c-w>w')
      eng.feed(':5<cr>')
      assert.is_true(eng.wait_cursor(5))
      eng.feed('<f8>')
      eng.feed(':12<cr>')
      assert.is_true(eng.wait_cursor(12))
      eng.feed('<f8>')
      eng.feed('<f10>')

      assert.is_true(eng.wait_signs({cur = 'test.cpp:19', brk = {[1] = {5, 12}}}))

      -- Switch to the first backend
      eng.feed('1gt')
      assert.is_true(eng.wait_signs({cur = 'test.cpp:10', brk = {[1] = {11}}}))

      -- Quit
      eng.feed(':GdbDebugStop<cr>')

      -- Switch back to the second backend
      eng.feed('2gt')
      assert.is_true(eng.wait_signs({cur = 'test.cpp:19', brk = {[1] = {5, 12}}}))

      -- The last debugger is quit automatically
    end)
  end)

end)
