local conf = require'conftest'
local eng = require'engine'

local function bashdb_stops(action)
  conf.post_terminal_end(function()
    conf.count_stops(action)
  end)
end

describe("bashdb", function()

  if conf.backend_names.bashdb == nil then
    return
  end

  it('generic use case', function()
    bashdb_stops(function(count_stops)
      eng.feed(' db<cr>')
      assert.is_true(count_stops.wait(1))
      assert.is_true(eng.wait_signs({cur = 'main.sh:22'}))

      eng.feed('tbreak Main<cr>')
      eng.feed('<esc>')
      eng.feed('<f5>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:16'}))

      eng.feed('<f10>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:17'}))

      eng.feed('<f10>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:18'}))

      eng.feed('<f11>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:7'}))

      eng.feed('<c-p>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:18'}))

      eng.feed('<c-n>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:7'}))

      eng.feed('<f12>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:17'}))

      eng.feed('<f5>')
      assert.is_true(eng.wait_signs({}))
    end)
  end)

  it('toggling breakpoints', function()
    bashdb_stops(function(count_stops)
      eng.feed(' db<cr>')
      assert.is_true(count_stops.wait(1))
      eng.feed('<esc><c-w>k')
      eng.feed(':4<cr>')
      assert.is_true(eng.wait_cursor(4))
      eng.feed('<f8>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:22', brk = {[1] = {4}}}))

      eng.exe('GdbContinue')
      assert.is_true(eng.wait_signs({cur = 'main.sh:4', brk = {[1] = {4}}}))

      eng.feed('<f8>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:4'}))
    end)
  end)

  it('last command is repeated on empty input', function()
    bashdb_stops(function(count_stops)
      eng.feed(' db<cr>')
      assert.is_true(count_stops.wait(1))
      assert.is_true(eng.wait_signs({cur = 'main.sh:22'}))

      eng.feed('tbreak Main<cr>')
      eng.feed('cont<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:16'}))

      eng.feed('n<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:17'}))
      eng.feed('<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:18'}))
      eng.feed('<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.sh:17'}))
    end)
  end)

end)
