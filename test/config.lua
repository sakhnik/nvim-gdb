local utils = require'nvimgdb.utils'
local thr = require'thread'
local eng = require'engine'

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
  assert.is_true(cursor_line >= last_line - win_height, "cursor in the terminal window should be visible")
end

function C.post(action)
  -- Prepare and check tabpages for every test.
  -- Quit debugging and do post checks.

  while vim.fn.tabpagenr('$') > 1 do
    thr.y(0, vim.cmd('tabclose $'))
  end
  local num_bufs = eng.count_buffers()

  action()

  thr.y(0, vim.cmd("GdbDebugStop"))
  assert.equals(1, vim.fn.tabpagenr('$'), "No rogue tabpages")
  --assert {} == eng.get_signs()
  assert.equals(0, eng.count_termbuffers(), "No rogue terminal buffers")
  assert.equals(num_bufs, eng.count_buffers(), "No new buffers have left")

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= 1 and vim.api.nvim_buf_is_loaded(buf) then
      thr.y(0, vim.cmd("bdelete! " .. buf))
      -- TODO investigate why
      --vim.api.nvim_buf_delete(buf, {force = true})
    end
  end
end

--function C.backend(action)
--  C.post(function()
--    C.terminal_end(function()
--      for name, backend in pairs(C.backends) do
--        action(name, backend)
--      end
--    end)
--  end)
--end

function C.backend(action)
  for _, backend in pairs(C.backends) do
    action(backend)
  end
end

return C
