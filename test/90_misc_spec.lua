local conf = require'conftest'
local eng = require'engine'

describe("misc", function()

  it('ensure that keymaps are defined in the jump window when navigating', function()
    conf.post_terminal_end(function()

      local function get_map()
        return vim.fn.execute("map <c-n>")
      end
      local function contains(b)
        return function(a) return a:find(b) ~= nil end
      end

      eng.feed(":e main.py\n")
      assert.is_true(eng.wait_for(get_map, contains("No mapping found")))
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = "main.py:1"}))
      eng.feed('<esc>')
      assert.is_true(eng.wait_for(get_map, contains("GdbFrameDown")))
      eng.feed('<c-w>w')
      assert.is_true(eng.wait_for(get_map, contains("GdbFrameDown")))
      eng.feed(':tabnew\n')
      eng.feed(':e main.py\n')
      assert.is_true(eng.wait_for(get_map, contains("No mapping found")))
      eng.feed('gt')
      assert.is_true(eng.wait_for(get_map, contains("GdbFrameDown")))
      eng.exe("bw!")
    end)
  end)

end)
