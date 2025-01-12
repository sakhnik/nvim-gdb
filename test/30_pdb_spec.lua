local conf = require'conftest'
local eng = require'engine'

describe("pdb", function()

  it('generic use case', function()
    conf.post_terminal_end(function()
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('tbreak _main<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1', brk = {[1] = {15}}}))
      eng.feed('cont<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:15'}))
      eng.feed('<esc>')

      eng.feed('<f10>')
      assert.is_true(eng.wait_signs({cur = 'main.py:16'}))

      eng.feed('<f11>')
      assert.is_true(eng.wait_signs({cur = 'main.py:8'}))

      eng.feed('<c-p>')
      assert.is_true(eng.wait_signs({cur = 'main.py:16'}))

      eng.feed('<c-n>')
      assert.is_true(eng.wait_signs({cur = 'main.py:8'}))

      eng.feed('<f12>')
      assert.is_true(eng.wait_signs({cur = 'main.py:10'}))

      eng.feed('<f5>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
    end)
  end)

  it('toggling breakpoints', function()
    conf.post_terminal_end(function()
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('<esc>')

      eng.feed('<c-w>k')
      eng.feed(':5<cr>')
      assert.is_true(eng.wait_cursor(5))
      eng.feed('<f8>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1', brk = {[1] = {5}}}))

      eng.exe('GdbContinue')
      assert.is_true(eng.wait_signs({cur = 'main.py:5', brk = {[1] = {5}}}))

      eng.feed('<f8>')
      assert.is_true(eng.wait_signs({cur = 'main.py:5'}))
    end)
  end)

  it('toggling breakpoints while navigating', function()
    conf.post_terminal_end(function()
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('<esc>')

      eng.feed('<c-w>w')
      eng.feed(':5<cr>')
      assert.is_true(eng.wait_cursor(5))
      eng.feed('<f8>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1', brk = {[1] = {5}}}))

      -- Go to another file
      eng.feed(':e lib.py<cr>')
      eng.feed(':5<cr>')
      assert.is_true(eng.wait_cursor(5))
      eng.feed('<f8>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1', brk = {[1] = {5}}}))
      eng.feed(':7<cr>')
      assert.is_true(eng.wait_cursor(7))
      eng.feed('<f8>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1', brk = {[1] = {5, 7}}}))

      -- Return to the original file
      eng.feed(':e main.py<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1', brk = {[1] = {5}}}))
    end)
  end)

  it('run until line', function()
    conf.post_terminal_end(function()
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('tbreak _main<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1', brk = {[1] = {15}}}))
      eng.feed('cont<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:15'}))
      eng.feed('<esc>')

      eng.feed('<c-w>w')
      eng.feed(':18<cr>')
      assert.is_true(eng.wait_cursor(18))
      eng.feed('<f4>')
      assert.is_true(eng.wait_signs({cur = 'main.py:18'}))
    end)
  end)

  it('eval <word>', function()
    conf.post_terminal_end(function()
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('tbreak _main<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1', brk = {[1] = {15}}}))
      eng.feed('cont<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:15'}))
      eng.feed('<esc>')
      eng.feed('<c-w>w')
      eng.feed('<f10>')
      assert.is_true(eng.wait_signs({cur = 'main.py:16'}))

      eng.feed('^<f9>')
      assert.equals('print(_foo)', NvimGdb.here._last_command)

      eng.feed('viW')
      eng.feed(':GdbEvalRange<cr>')
      assert.equals('print(_foo(i))', NvimGdb.here._last_command)
    end)
  end)

  it('launch expand()', function()
    conf.post_terminal_end(function()
      eng.feed(':e main.py<cr>')    -- Open a file to activate %
      eng.feed(' dp')
      -- Substitute main.py by % and launch
      eng.feed('<c-w><c-w><c-w>%<cr>')
      -- Ensure a debugging session has started
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      -- Clean up the main tabpage
      eng.feed('<esc><c-w>w')
      eng.exe('bw!')
    end)
  end)

  it('the last command is repeated on empty input', function()
    conf.post_terminal_end(function()
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('tbreak _main<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1', brk = {[1] = {15}}}))
      eng.feed('cont<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:15'}))

      eng.feed('n<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:16'}))
      eng.feed('<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:15'}))
    end)
  end)

end)
