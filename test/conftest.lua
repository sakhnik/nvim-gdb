local utils = require'nvimgdb.utils'
local thr = require'thread'
local eng = require'engine'
local busted = require'busted'

---@class Conf
---@field aout string Executable file name
local C = {}

C.aout = utils.is_windows and 'a.exe' or 'a.out'

C.backend_names = {}
for name in io.lines("backends.txt") do
  C.backend_names[name] = true
end

C.backends = {}
if C.backend_names.gdb ~= nil then
  C.backends.gdb = {
      name = 'gdb',
      launch = ' dd '.. C.aout .. '<cr>',
      tbreak_main = 'tbreak main<cr>',
      break_main = 'break main<cr>',
      break_bar = 'break Bar<cr>',
      launchF = ':GdbStart gdb -q %s<cr>',
      watchF = 'watch %s<cr>',
  }
end
if C.backend_names.lldb ~= nil then
  C.backends.lldb = {
      name = 'lldb',
      launch = ' dl ' .. C.aout .. '<cr>',
      tbreak_main = 'breakpoint set -o true -n main<cr>',
      break_main = 'breakpoint set -n main<cr>',
      break_bar = 'breakpoint set --fullname Bar<cr>',
      launchF = ':GdbStartLLDB lldb %s<cr>',
      watchF = 'watchpoint set variable %s<cr>',
  }
end

function C.terminal_end(action)
  action()
  local cursor_line = vim.api.nvim_win_get_cursor(NvimGdb.i().client.win)[1]
  local last_line = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(NvimGdb.i().client.win))
  local win_height = vim.api.nvim_win_get_height(NvimGdb.i().client.win)
  busted.assert.is_true(cursor_line >= last_line - win_height, "cursor in the terminal window should be visible")
end

function C.post(action)
  -- Prepare and check tabpages for every test.
  -- Quit debugging and do post checks.

  local mode = vim.api.nvim_get_mode()
  if mode.mode == 'i' then
    eng.feed("<esc>")
  elseif mode.mode == 't' then
    eng.feed("<c-\\><c-n>")
  end

  while vim.fn.tabpagenr('$') > 1 do
    thr.y(0, vim.cmd('tabclose $'))
  end

  action()

  thr.y(0, vim.cmd("GdbDebugStop"))
  busted.assert.equals(1, vim.fn.tabpagenr('$'), "No rogue tabpages")
  busted.assert.are.same({}, eng.get_signs(), "No rogue signs")
  busted.assert.are.same({}, eng.get_termbuffers(), "No rogue terminal buffers")

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= 1 and vim.api.nvim_buf_is_loaded(buf) then
      thr.y(0, vim.cmd("bdelete! " .. buf))
      -- TODO investigate why
      --vim.api.nvim_buf_delete(buf, {force = true})
    end
  end
end

function C.post_terminal_end(action)
  C.post(function()
    C.terminal_end(action)
  end)
end

function C.backend(action)
  for _, backend in pairs(C.backends) do
    action(backend)
  end
end

---Allow waiting for the specific count of debugger prompts appeared
---@param action function(prompt) @test actions
function C.count_stops(action)
  local prompt_count = 0
  local auid = vim.api.nvim_create_autocmd('User', {
    pattern = 'NvimGdbQuery',
    callback = function()
      prompt_count = prompt_count + 1
    end
  })

  local prompt = {
    reset = function() prompt_count = 0 end,
    wait = function(count, timeout_ms)
      return eng.wait_for(
        function() return prompt_count end,
        function(val) return val >= count end,
        timeout_ms
      )
    end
  }

  action(prompt)

  vim.api.nvim_del_autocmd(auid)
end

function C.config_test(action)
  C.post_terminal_end(action)
  for scope in ("bwtg"):gmatch'.' do
    for k, _ in pairs(vim.fn.eval(scope .. ':')) do
      if type(k) == "string" and k:find('^nvimgdb_') then
        vim.api.nvim_command('unlet ' .. scope .. ':' .. k)
      end
    end
  end
end

return C
