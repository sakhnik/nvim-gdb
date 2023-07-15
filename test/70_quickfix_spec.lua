local conf = require'conftest'
local eng = require'engine'
local thr = require'thread'

describe("quickfix", function()
  conf.backend(function(backend)

    it(backend.name .. ' breakpoint location list in C++', function()
      conf.post_terminal_end(function()
        conf.count_stops(function(count_stops)
          eng.feed(backend.launch)
          assert.is_true(eng.wait_paused(5000))
          eng.feed('b main<cr>')
          eng.feed('b Foo<cr>')
          count_stops.reset()
          eng.feed('b Bar<cr>')
          assert.is_true(count_stops.wait(1))
          eng.feed('<esc>')
          eng.feed('<c-w>w')
          eng.feed(':aboveleft GdbLopenBreakpoints\n')
          assert.is_true(
            eng.wait_for(
              function() return #vim.fn.getloclist(0) end,
              function(r) return r > 0 end
            )
          )

          eng.feed('<c-w>k')
          eng.feed(':ll<cr>')
          assert.is_true(
            eng.wait_for(
              function() return vim.fn.line('.') end,
              function(r) return r == 17 end
            )
          )
          eng.feed(':lnext<cr>')
          assert.equals(10, vim.fn.line('.'))
          eng.feed(':lnext<cr>')
          assert.equals(5, vim.fn.line('.'))
          eng.feed(':lnext<cr>')
          assert.equals(5, vim.fn.line('.'))
        end)
      end)
    end)

    it(backend.name .. ' backtrace location list in C++', function()
      conf.post_terminal_end(function()
        eng.feed(backend.launch)
        assert.is_true(eng.wait_paused(5000))
        eng.feed('b Bar<cr>')
        eng.feed('run<cr>')
        assert.is_true(eng.wait_signs({cur = 'test.cpp:5', brk = {[1] = {5}}}))
        eng.feed('<esc>')
        eng.feed('<c-w>w')
        eng.feed(':belowright GdbLopenBacktrace<cr>')
        assert.is_true(
          eng.wait_for(
            function() return #vim.fn.getloclist(0) end,
            function(r) return r > 0 end
          )
        )
        eng.feed('<c-w>j')
        eng.feed(':ll<cr>')
        assert.is_true(
          eng.wait_for(
            function() return vim.fn.line('.') end,
            function(r) return r == 5 end
          )
        )
        eng.feed(':lnext<cr>')
        assert.equals(12, vim.fn.line('.'))
        eng.feed(':lnext<cr>')
        assert.equals(19, vim.fn.line('.'))
      end)
    end)


  end)

  it('breakpoint location list in PDB', function()
    conf.post_terminal_end(function()
      conf.count_stops(function(count_stops)
        eng.feed(' dp<cr>')
        assert.is_true(count_stops.wait(1))
        eng.feed('b _main<cr>')
        assert.is_true(count_stops.wait(2))
        eng.feed('b _foo<cr>')
        assert.is_true(count_stops.wait(3))
        eng.feed('b _bar<cr>')
        assert.is_true(count_stops.wait(4))
        eng.feed('<esc>')
        eng.feed('<c-w>w')
        eng.feed(':GdbLopenBreakpoints<cr>')
        assert.is_true(
          eng.wait_for(
            function() return #vim.fn.getloclist(0) end,
            function(r) return r > 0 end
          )
        )
        eng.feed('<c-w>j')
        eng.feed(':ll<cr>')
        assert.is_true(
          eng.wait_for(
            function() return vim.fn.line('.') end,
            function(r) return r == 14 end
          )
        )
        eng.feed(':lnext<cr>')
        assert.equals(8, vim.fn.line('.'))
        eng.feed(':lnext<cr>')
        assert.equals(4, vim.fn.line('.'))
        eng.feed(':lnext<cr>')
        assert.equals(4, vim.fn.line('.'))
      end)
    end)
  end)

  it('backtrace location list in PDB', function()
    conf.post_terminal_end(function()
      conf.count_stops(function(count_stops)
        eng.feed(' dp<cr>')
        assert.is_true(count_stops.wait(1))
        eng.feed('b _bar<cr>')
        assert.is_true(count_stops.wait(2))
        eng.feed('cont<cr>')
        assert.is_true(eng.wait_signs({cur = 'main.py:5', brk = {[1] = {4}}}))
        eng.feed('<esc>')
        eng.feed('<c-w>w')
        eng.feed(':GdbLopenBacktrace<cr>')
        assert.is_true(
          eng.wait_for(
            function() return #vim.fn.getloclist(0) end,
            function(r) return r > 0 end
          )
        )
        eng.feed('<c-w>j')
        eng.feed(':lnext<cr>')
        eng.feed(':lnext<cr>')
        assert.is_true(
          eng.wait_for(
            function() return vim.fn.line('.') end,
            function(r) return r == 22 end
          )
        )
        eng.feed(':lnext<cr>')
        assert.equals(16, vim.fn.line('.'))
        eng.feed(':lnext<cr>')
        assert.equals(11, vim.fn.line('.'))
        eng.feed(':lnext<cr>')
        assert.equals(5, vim.fn.line('.'))
      end)
    end)
  end)

  if conf.backend_names.bashdb ~= nil then

    it('breakpoint location list in BashDB', function()
      conf.post_terminal_end(function()
        eng.feed(' db\n')
        assert.is_true(eng.wait_paused())
        eng.feed('b Main\n')
        eng.feed('b Foo\n')
        eng.feed('b Bar\n')
        eng.feed('<esc>')
        eng.feed(':GdbLopenBreakpoints\n')
        thr.y(300)
        eng.feed('<c-w>k')
        eng.feed(':ll\n')
        assert.is_true(
          eng.wait_for(
            function() return vim.fn.line('.') end,
            function(r) return r == 16 end
          )
        )
        eng.feed(':lnext\n')
        assert.equals(7, vim.fn.line('.'))
        eng.feed(':lnext\n')
        assert.equals(3, vim.fn.line('.'))
        eng.feed(':lnext\n')
        assert.equals(3, vim.fn.line('.'))
      end)
    end)

    it('breakpoint location list in BashDB', function()
      conf.post_terminal_end(function()
        eng.feed(' db\n')
        assert.is_true(eng.wait_paused())
        eng.feed('b Bar\n')
        eng.feed('cont\n')
        assert.is_true(eng.wait_signs({cur = 'main.sh:3', brk = {[1] = {3}}}))
        eng.feed('<esc>')
        eng.feed(':GdbLopenBacktrace\n')
        thr.y(300)
        eng.feed('<c-w>k')
        eng.feed(':ll\n')
        assert.is_true(
          eng.wait_for(
            function() return vim.fn.line('.') end,
            function(r) return r == 3 end
          )
        )
        eng.feed(':lnext\n')
        assert.equals(11, vim.fn.line('.'))
        eng.feed(':lnext\n')
        assert.equals(18, vim.fn.line('.'))
        eng.feed(':lnext\n')
        assert.equals(22, vim.fn.line('.'))
      end)
    end)

  end

end)
