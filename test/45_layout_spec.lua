local eng = require'engine'
local conf = require'conftest'

describe("layout", function()

  it("terminal window above", function()
    conf.config_test(function()
      vim.w.nvimgdb_termwin_command = "aboveleft new"
      eng.exe('e config.py')
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('<esc>')
      eng.feed('<c-w>j')
      assert.equals('main.py', vim.fn.expand("%:t"))
    end)
  end)

  it("terminal window to the right", function()
    conf.config_test(function()
      vim.w.nvimgdb_termwin_command = "belowright vnew"
      eng.exe('e config.py')
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('<esc>')
      eng.feed('<c-w>h')
      assert.equals('main.py', vim.fn.expand("%:t"))
    end)
  end)

  it("terminal window in the current window below the jump window", function()
    conf.config_test(function()
      vim.w.nvimgdb_termwin_command = ""
      eng.exe('e config.py')
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('<esc>')
      eng.feed('<c-w>k')
      assert.equals('main.py', vim.fn.expand("%:t"))
    end)
  end)

  it("terminal window in the current window below the jump window", function()
    conf.config_test(function()
      vim.w.nvimgdb_termwin_command = ""
      vim.t.nvimgdb_codewin_command = "belowright new"
      eng.exe('e config.py')
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('<esc>')
      eng.feed('<c-w>j')
      assert.equals('main.py', vim.fn.expand("%:t"))
    end)
  end)

  it("terminal window in the current window left of the jump window", function()
    conf.config_test(function()
      vim.w.nvimgdb_termwin_command = ""
      vim.t.nvimgdb_codewin_command = "rightbelow vnew"
      eng.exe('e config.py')
      eng.feed(' dp<cr>')
      assert.is_true(eng.wait_signs({cur = 'main.py:1'}))
      eng.feed('<esc>')
      eng.feed('<c-w>l')
      assert.equals('main.py', vim.fn.expand("%:t"))
    end)
  end)

end)
