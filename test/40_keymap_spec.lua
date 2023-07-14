local eng = require'engine'
local conf = require'conftest'

describe("keymaps", function()

  local backend = nil
  if conf.backends.gdb ~= nil then
    backend = conf.backends.gdb
  elseif conf.backends.lldb ~= nil then
    backend = conf.backends.lldb
  end
  if backend == nil then
    pending("No usable C++ debugger backends")
  end

  local function config_test(action)
    conf.post_terminal_end(action)
    for scope in ("bwtg"):gmatch'.' do
      for k, _ in pairs(vim.fn.eval(scope .. ':')) do
        if type(k) == "string" and k:find('^nvimgdb_') then
          vim.api.nvim_command('unlet ' .. scope .. ':' .. k)
        end
      end
    end
  end

  local function keymap_hooks()
    -- This function can be used as an example of how to add custom keymaps
    -- Flags for test keymaps
    vim.g.test_tkeymap = 0
    vim.g.test_keymap = 0

    -- A hook function to set keymaps in the terminal window
    local function my_set_tkeymaps()
      NvimGdb.i().keymaps:set_t()
      vim.cmd([[tnoremap <buffer> <silent> ~tkm <c-\><c-n>:let g:test_tkeymap = 1<cr>i]])
    end

    -- A hook function to key keymaps in the code window.
    -- Will be called every time the code window is entered
    local function my_set_keymaps()
      -- First set up the stock keymaps
      NvimGdb.i().keymaps:set()

      -- Then there can follow any additional custom keymaps. For example,
      -- One custom programmable keymap needed in some tests
      vim.cmd([[nnoremap <buffer> <silent> ~tn :let g:test_keymap = 1<cr>]])
    end

    -- A hook function to unset keymaps in the code window
    -- Will be called every time the code window is left
    local function my_unset_keymaps()
      -- Unset the custom programmable keymap created in MySetKeymap
      vim.cmd([[nunmap <buffer> ~tn]])

      -- Then unset the stock keymaps
      NvimGdb.i().keymaps:unset()
    end

    -- Declare in the configuration that there are custom keymap handlers
    vim.g.nvimgdb_config_override = {
      set_tkeymaps = my_set_tkeymaps,
      set_keymaps = my_set_keymaps,
      unset_keymaps = my_unset_keymaps,
    }
  end

  it("custom programmable keymaps", function()
    config_test(function()
      keymap_hooks()
      eng.feed(backend.launchF:format(""))

      assert.equals(0, vim.g.test_tkeymap)
      eng.feed('~tkm')
      assert.is_true(eng.wait_for(function() return vim.g.test_tkeymap end, function(v) return v == 1 end))
      eng.feed('<esc>')
      assert.equals(0, vim.g.test_keymap)
      eng.feed('~tn')
      assert.is_true(eng.wait_for(function() return vim.g.test_keymap end, function(v) return v == 1 end))
      vim.g.test_tkeymap = 0
      vim.g.test_keymap = 0
      eng.feed('<c-w>w')
      assert.equals(0, vim.g.test_keymap)
      eng.feed('~tn')
      assert.is_true(eng.wait_for(function() return vim.g.test_keymap end, function(v) return v == 1 end))
      eng.exe('let g:test_keymap = 0')
    end)
  end)

  it("conflicting keymap", function()
    config_test(function()
      vim.g.nvimgdb_config = {key_next = '<f5>', key_prev = '<f5>'}
      eng.feed(backend.launchF:format(""))

      local count = 0
      for key, _ in pairs(NvimGdb.i().config.config) do
        if key:match("^key_.*") ~= nil then
          count = count + 1
        end
      end

      assert.equals(1, count)
      -- Check that the cursor is moving freely without stucking
      eng.feed('<c-\\><c-n>')
      eng.feed('<c-w>w')
      eng.feed('<c-w>w')
    end)
  end)

  it("override a key", function()
    config_test(function()
      vim.g.nvimgdb_config_override = {key_next = '<f2>'}
      eng.feed(backend.launchF:format(""))
      local key = NvimGdb.i().config:get("key_next")
      assert.equals('<f2>', key)
    end)
  end)

  it("override assumes priority in a conflict", function()
    config_test(function()
      vim.g.nvimgdb_config_override = {key_next = '<f8>'}
      eng.feed(backend.launchF:format(""))
      local res = NvimGdb.i().config:get_or("key_breakpoint", 0)
      assert.equals(0, res)
    end)
  end)

  it("override a single key", function()
    config_test(function()
      vim.g.nvimgdb_key_next = '<f3>'
      eng.feed(backend.launchF:format(""))
      local key = NvimGdb.i().config:get_or("key_next", 0)
      assert.equals('<f3>', key)
    end)
  end)

  it("override a single key, priority", function()
    config_test(function()
      vim.g.nvimgdb_key_next = '<f8>'
      eng.feed(backend.launchF:format(""))
      local res = NvimGdb.i().config:get_or("key_breakpoint", 0)
      assert.equals(0, res)
    end)
  end)

  it("smoke", function()
    config_test(function()
      vim.g.nvimgdb_config_override = {key_next = '<f5>'}
      vim.g.nvimgdb_key_step = '<f5>'
      eng.feed(backend.launchF:format(""))
      assert.equals(0, NvimGdb.i().config:get_or("key_continue", 0))
      assert.equals(0, NvimGdb.i().config:get_or("key_next", 0))
      assert.equals('<f5>', NvimGdb.i().config:get_or("key_step", 0))
    end)
  end)

end)
