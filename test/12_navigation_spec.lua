local conf = require'conftest'
local eng = require'engine'

describe("navigation", function()
  conf.backend(function(backend)
    it(backend.name .. ' no undesired jump', function()
      if backend.name == 'gdb' then
        conf.post_terminal_end(function()
          eng.feed(backend.launch)
          assert.is_true(eng.wait_paused())
          eng.feed("b Baz<cr>")
          eng.feed("r<cr>")
          assert.is_true(eng.wait_signs({cur = 'lib.hpp:7', brk = {[1] = {7}}}))
          eng.feed("n<cr>")
          assert.is_true(eng.wait_signs({cur = 'lib.hpp:8', brk = {[1] = {7}}}))
          eng.feed('<esc><c-w>w')
          eng.feed(':e src/test.cpp<cr>')
          -- check that the breakpoints aren't visible (moved to test.cpp)
          assert.is_true(eng.wait_signs({cur = 'lib.hpp:8'}))
          eng.feed('<c-w>wi')
          eng.feed('p')
          -- check that we stay in test.cpp
          assert.is_true(eng.wait_signs({cur = 'lib.hpp:8'}))
          eng.feed(' ret<cr>')
          assert.is_true(eng.wait_signs({cur = 'lib.hpp:8'}))
        end)
      end
    end)
  end)
end)
