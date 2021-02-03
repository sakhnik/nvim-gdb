-- vim: set et ts=2 sw=2:

local log = require 'nvimgdb.log'

local C = {}
C.efmmgr = require 'nvimgdb.efmmgr'
C.__index = C

-- Create a new instance of the debugger in the current tabpage.
function C.new(backend_name, proxy_cmd, client_cmd)
  local self = setmetatable({}, C)

  self.config = require'nvimgdb.config'.new()

  -- The last executed debugger command for testing
  self._last_command = nil

  -- Create new tab for the debugging view and split horizontally
  vim.cmd('tabnew')
  vim.wo.winfixwidth = false
  vim.wo.winfixheight = false
  vim.cmd('silent wincmd o')

  -- Get the selected backend module
  self.backend = require "nvimgdb.backend".choose(backend_name)

  -- Go to the other window and spawn gdb client
  self.client = require'nvimgdb.client'.new(proxy_cmd, client_cmd)

  -- Initialize connection to the side channel
  self.proxy = require'nvimgdb.proxy'.new(self.client)

  -- Initialize breakpoint tracking
  self.breakpoint = require'nvimgdb.breakpoint'.new(self.config, self.proxy, self.backend.query_breakpoints)

  -- Initialize the keymaps subsystem
  self.keymaps = require'nvimgdb.keymaps'.new(self.config)

  -- Initialize current line tracking
  self.cursor = require'nvimgdb.cursor'.new(self.config)

  -- Initialize the windowing subsystem
  self.win = require'nvimgdb.win'.new(self.config, self.keymaps, self.cursor, self.client, self.breakpoint)

  -- Initialize the parser
  local parser_actions = require'nvimgdb.parser_actions'.new(self.cursor, self.win)
  self.parser = self.backend.create_parser(parser_actions)

  -- Setup 'errorformat' for the given backend.
  C.efmmgr.setup(self.backend.get_error_formats())

  -- Spawn the debugger, the parser should be ready by now.
  self.client:start(self.parser)
  vim.cmd("doautocmd User NvimGdbStart")

  -- Start insert mode in the GDB window
  vim.fn.feedkeys("i")

  return self
end

-- The late initialization items that require accessing via tabpage.
function C:postinit()
  -- Set initial keymaps in the terminal window.
  assert(vim.api.nvim_get_current_win() == self.client.win)
  self.keymaps:dispatch_set_t()
  self.keymaps:dispatch_set()
end

-- Finish up the debugging session.
function C:cleanup(tab)
  vim.cmd("doautocmd User NvimGdbCleanup")

  -- Remove from 'errorformat' for the given backend.
  C.efmmgr.teardown(self.backend.get_error_formats())

  -- Clean up the breakpoint signs
  self.breakpoint:reset_signs()

  -- Clean up the current line sign
  self.cursor:hide()

  -- Clean up the windows and buffers
  self.win:cleanup()

  -- Close connection to the side channel
  self.proxy:cleanup()

  -- Close the debugger backend
  self.client:cleanup()

  -- Close the windows and the tab
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    if tabpage == tab then
      vim.cmd("tabclose! " .. vim.api.nvim_tabpage_get_number(tabpage))
      break
    end
  end

  -- TabEnter isn't fired automatically when a tab is closed
  nvimgdb.i(0):on_tab_enter()
end

-- Send a command to the debugger.
function C:send(cmd, a1, a2, a3)
  if cmd ~= nil then
    local command = self.backend:translate_command(cmd):format(a1, a2, a3)
    self.client:send_line(command)
    self._last_command = command  -- Remember the command for testing
  else
    self.client:interrupt()
  end
end

-- Execute a custom debugger command and return its output.
function C:custom_command(cmd)
  return self.proxy:query('handle-command ' .. cmd)
end

--[[Create a window to watch for a debugger expression.

The output of the expression or command will be displayed
in that window.
]]
function C:create_watch(cmd)
  vim.cmd("vnew | set readonly buftype=nowrite")
  self.keymaps:dispatch_set()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, cmd)

  local cur_tabpage = vim.api.nvim_get_current_tabpage()
  local augroup_name = "NvimGdbTab" .. cur_tabpage .. "_" .. buf

  vim.cmd("augroup " .. augroup_name)
  vim.cmd("autocmd!")
  vim.cmd("autocmd User NvimGdbQuery" ..
          " call nvim_buf_set_lines(" .. buf .. ", 0, -1, 0," ..
          " split(GdbCustomCommand('" .. cmd .. "'), '\\n'))")
  vim.cmd("augroup END")

  -- Destroy the autowatch automatically when the window is gone.
  vim.cmd("autocmd BufWinLeave <buffer> call" ..
          " nvimgdb#ClearAugroup('" .. augroup_name .. "')")
  -- Destroy the watch buffer.
  vim.cmd("autocmd BufWinLeave <buffer> call timer_start(100," ..
          " { -> execute('bwipeout! " .. buf .. "') })")
  -- Return the cursor to the previous window
  vim.cmd("wincmd l")
end

-- Toggle breakpoint in the cursor line.
function C:breakpoint_toggle()
  if self.parser:is_running() then
    -- pause first
    self.client:interrupt()
  end
  local buf = vim.api.nvim_get_current_buf()
  local file_name = vim.fn.expand('#' .. buf .. ':p')
  local line_nr = vim.fn.line(".")
  local breaks = self.breakpoint:get_for_file(file_name, tostring(line_nr))

  if #breaks > 0 then
    -- There already is a breakpoint on this line: remove
    local del_br = self.backend:translate_command('delete_breakpoints')
    self.client:send_line(del_br .. ' ' .. breaks[#breaks])
  else
    local set_br = self.backend:translate_command('breakpoint')
    self.client:send_line(set_br .. ' ' .. file_name .. ':' .. line_nr)
  end
end

function C:breakpoint_clear_all()
  -- Clear all breakpoints.
  if self.parser:is_running() then
    -- pause first
    self.client:interrupt()
  end
  -- The breakpoint signs will be requeried later automatically
  self:send('delete_breakpoints')
end

-- Actions to execute when a tabpage is entered.
function C:on_tab_enter()
  -- Restore the signs as they may have been spoiled
  if self.parser:is_paused() then
    self.cursor:show()
  end
  -- Ensure breakpoints are shown if are queried dynamically
  self.win:query_breakpoints()
end

-- Actions to execute when a tabpage is left.
function C:on_tab_leave()
  -- Hide the signs
  self.cursor:hide()
  self.breakpoint:clear_signs()
end

-- Actions to execute when a buffer is entered.
function C:on_buf_enter()
  -- Apply keymaps to the jump window only.
  if vim.bo.buftype ~= 'terminal' and self.win:is_jump_window_active() then
    -- Make sure the cursor stay visible at all times
    local scroll_off = self.config:get('set_scroll_off')
    if scroll_off ~= nil then
      vim.cmd("if !&scrolloff" ..
              " | setlocal scrolloff=" .. scroll_off ..
              " | endif")
    end
    self.keymaps:dispatch_set()
    -- Ensure breakpoints are shown if are queried dynamically
    self.win:query_breakpoints()
  end
end

-- Actions to execute when a buffer is left.
function C:on_buf_leave()
  if vim.bo.buftype == 'terminal' then
    -- Move the cursor to the end of the buffer
    vim.cmd("$")
    return
  end
  if self.win:is_jump_window_active() then
    self.keymaps:dispatch_unset()
  end
end

-- Load backtrace or breakpoints into the location list.
function C:lopen(kind, mods)
  local cmd = ''
  if kind == "backtrace" then
    cmd = self.backend:translate_command('bt')
  elseif kind == "breakpoints" then
    cmd = self.backend:translate_command('info breakpoints')
  else
    log.warn({"Unknown lopen kind", kind})
    return
  end
  self.win:lopen(cmd, kind, mods)
end

function C:get_for_llist(kind, cmd)
  local output = self:custom_command(cmd)
  local lines = {}
  for line in output:gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
  end
  return lines
end

return C
