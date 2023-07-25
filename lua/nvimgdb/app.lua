-- vim: set et ts=2 sw=2:

local log = require 'nvimgdb.log'
local NvimGdb = require'nvimgdb'

---@class App @debugger manager
---@field private destructors table<string, function> @custom destructors to be executed during cleanup
---@field private config Config @resolved configuration
---@field private backend Backend @selected backend-specific routines
---@field private client Client @spawned debugger manager
---@field private proxy Proxy @connection to the side channel
---@field private breakpoint Breakpoint @breakpoint sign manager
---@field private keymaps Keymaps @dynamic keymaps manager
---@field private cursor Cursor @current line sign nandler
---@field private win Win @jump window manager
---@field private parser ParserImpl @debugger output parser
---@field private tabpage_created boolean @indicates whether the tabpage was created and needs to be closed during cleanup
local App = {}
App.efmmgr = require 'nvimgdb.efmmgr'
App.__index = App

-- Create a new instance of the debugger in the current tabpage.
-- @param backend_name string @backend name
-- @param client_cmd string[] @debugger launching command
-- @return App @new instance
function App.new(backend_name, client_cmd)
  log.debug({"function App.new(", backend_name, client_cmd, ")"})
  local self = setmetatable({}, App)

  -- destructors to be executed during cleanup()
  self.destructors = {}

  self.config = require'nvimgdb.config'.new()

  -- The last executed debugger command for testing
  self._last_command = nil

  local edited_buf = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_loaded(edited_buf) or vim.api.nvim_buf_get_option(edited_buf, 'buftype') == 'terminal' then
    edited_buf = nil
  end

  -- Check if a debugging session is already running in this tabpage
  self.tabpage_created = false
  if getmetatable(NvimGdb.i(true)) == App then
    -- Create new tab for the new debugging view
    vim.api.nvim_command('tabnew')
    vim.wo.winfixwidth = false
    vim.wo.winfixheight = false
    vim.api.nvim_command('silent wincmd o')
    self.tabpage_created = true
  end

  -- Current window will become the jump window
  local start_win = vim.api.nvim_get_current_win()

  -- Get the selected backend module
  self.backend = require("nvimgdb.backend." .. backend_name).new()

  -- Spawn gdb client in a new terminal window
  self.client = require'nvimgdb.client'.new(self.config, self.backend, client_cmd)
  if start_win == self.client.win then
    -- Apparently, the configuration has been overridden to use current window
    -- for the debugging terminal. Thus, a new window will be assigned or created
    -- for the source navigation.
    start_win = nil
  end

  -- Initialize connection to the side channel
  self.proxy = require'nvimgdb.proxy'.new(self.client)

  -- Initialize breakpoint tracking
  self.breakpoint = require'nvimgdb.breakpoint'.new(self.config, self.proxy, self.backend.query_breakpoints)

  -- Initialize the keymaps subsystem
  self.keymaps = require'nvimgdb.keymaps'.new(self.config)

  -- Initialize current line tracking
  self.cursor = require'nvimgdb.cursor'.new(self.config)

  -- Initialize the windowing subsystem
  self.win = require'nvimgdb.win'.new(self.config, self.keymaps, self.cursor, self.client, self.breakpoint, start_win, edited_buf)

  -- Initialize the parser
  local parser_actions = require'nvimgdb.parser_actions'.new(self.cursor, self.win)
  self.parser = self.backend.create_parser(parser_actions, self.proxy)

  -- Setup 'errorformat' for the given backend.
  App.efmmgr.setup(self.backend.get_error_formats())

  return self
end

-- The late initialization items that require accessing via tabpage.
function App:postinit()
  log.debug({"function App:postinit()"})
  -- Spawn the debugger, the parser should be ready by now.
  self.client:start()
  vim.api.nvim_command("doautocmd User NvimGdbStart")

  -- Start insert mode in the debugger window
  vim.cmd("startinsert")
  -- Set initial keymaps in the terminal window.
  assert(vim.api.nvim_get_current_win() == self.client.win)
  self.keymaps:dispatch_set_t()
  self.keymaps:dispatch_set()
end

-- Finish up the debugging session.
-- @param tab number @tabpage number
function App:cleanup(tab)
  log.debug({"function App:cleanup(", tab, ")"})
  vim.api.nvim_command("doautocmd User NvimGdbCleanup")

  -- Execute scheduled destructors
  for _, destr in pairs(self.destructors) do
    destr()
  end

  -- Remove from 'errorformat' for the given backend.
  App.efmmgr.teardown(self.backend.get_error_formats())

  -- Destroy the parser
  self.parser:cleanup()

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

  -- Close the windows and the tab if necessary
  if self.tabpage_created then
    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
      if tabpage == tab then
        vim.api.nvim_command("tabclose! " .. vim.api.nvim_tabpage_get_number(tabpage))
        break
      end
    end

    -- TabEnter isn't fired automatically when a tab is closed
    NvimGdb.i(0):on_tab_enter()
  end
end

-- Send a command to the debugger.
-- @param cmd string @command template
-- @param a1 string @parameter 1 if command has format placeholders
-- @param a2 string @parameter 2
-- @param a3 string @parameter 3
function App:send(cmd, a1, a2, a3)
  log.debug({"function App:send(", cmd, a1, a2, a3, ")"})
  if cmd ~= nil then
    local command = self.backend:translate_command(cmd):format(a1, a2, a3)
    self.client:send_line(command)
    self._last_command = command  -- Remember the command for testing
  else
    self.client:interrupt()
  end
end

-- Execute a custom debugger command and return its output.
-- @param cmd string @debugger command to execute
-- @return string @fetched debugger output
function App:custom_command(cmd)
  log.debug({"function App:custom_command(", cmd, ")"})
  local response = self.proxy:query('handle-command ' .. cmd)
  if type(response) == 'string' then
    return response
  end
  if type(response) == 'table' and next(response) == nil then
    return ''
  end
  return tostring(response)
end

--[[Create a window to watch for a debugger expression.

The output of the expression or command will be displayed
in that window.
]]
-- @param cmd string @debugger command to watch
function App:create_watch(cmd, mods)
  log.debug({"function App:create_watch(", cmd, mods, ")"})
  if not mods or mods == '' then
    mods = 'vert'
  end
  vim.api.nvim_command(mods .. " new | set readonly buftype=nowrite")
  self.keymaps:dispatch_set()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, cmd)

  local cur_tabpage = vim.api.nvim_get_current_tabpage()
  local augroup_name = "NvimGdbTab" .. cur_tabpage .. "_" .. buf
  local augid = vim.api.nvim_create_augroup(augroup_name, { clear = false})

  -- Cleanup anything that could be left over if the autocmds haven't been fired.
  local function destr()
    vim.api.nvim_del_augroup_by_id(augid)
    -- Destroy the watch buffer.
    vim.fn.timer_start(100, function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, {force = true})
      end
    end)
  end
  self.destructors[augroup_name] = destr

  vim.api.nvim_create_autocmd({"User"}, {
    pattern = "NvimGdbQuery",
    group = augid,
    callback = function()
      -- The buffer may have been unloaded already
      if vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_set_lines(buf, 0, -1, 0, vim.fn.split(NvimGdb.i():custom_command(cmd), '\r*\n'))
      end
    end
  })

  -- Destroy the autowatch automatically when the window is gone.
  vim.api.nvim_create_autocmd({"BufWinLeave"}, {
    group = augid,
    buffer = buf,
    callback = function()
      destr()
      self.destructors[augroup_name] = nil
    end
  })


  -- Return the cursor to the previous window
  vim.api.nvim_command("wincmd l")
end

-- Toggle breakpoint in the cursor line
function App:breakpoint_toggle()
  log.debug({"function App:breakpoint_toggle()"})
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

-- Clear all breakpoints
function App:breakpoint_clear_all()
  log.debug({"function App:breakpoint_clear_all()"})
  if self.parser:is_running() then
    -- pause first
    self.client:interrupt()
  end
  -- The breakpoint signs will be requeried later automatically
  self:send('delete_breakpoints')
end

-- Actions to execute when a tabpage is entered.
function App:on_tab_enter()
  log.debug({"function App:on_tab_enter()"})
  -- Restore the signs as they may have been spoiled
  if self.parser:is_paused() then
    self.cursor:show()
  end
  -- Just in case that OnBufEnter isn't fired. Thus, multiple on_buf_enter() calls may occur.
  self:on_buf_enter()
end

-- Actions to execute when a tabpage is left.
function App:on_tab_leave()
  log.debug({"function App:on_tab_leave()"})
  -- Hide the signs
  self.cursor:hide()
  self.breakpoint:clear_signs()
  -- If the same buffer is focused on the other tabpage, OnBufLeave wouldn't be fired.
  self:on_buf_leave()
end

-- Actions to execute when a buffer is entered.
function App:on_buf_enter()
  log.debug({"function App:on_buf_enter()"})
  -- Apply keymaps to the jump window only.
  if vim.bo.filetype ~= 'nvimgdb' and self.win:is_jump_window_active() then
    self.keymaps:dispatch_set()
    -- Ensure breakpoints are shown if are queried dynamically
    self.win:query_breakpoints()
  end
end

-- Actions to execute when a buffer is left.
function App:on_buf_leave()
  log.debug({"function App:on_buf_leave()"})
  if vim.bo.filetype == 'nvimgdb' then
    -- Move the cursor to the end of the buffer
    local jump_bottom = self.config:get_or('jump_bottom_gdb_buf', false)
    if jump_bottom then
      vim.api.nvim_command("$")
    end
    return
  end
  if self.win:is_jump_window_active() then
    self.keymaps:dispatch_unset()
  end
end

-- Load backtrace or breakpoints into the location list.
-- @param kind "backtrace"|"breakpoints"
-- @param mods string @ command modifiers like "aboveleft"
function App:lopen(kind, mods)
  log.debug({"function App:lopen(", kind, mods, ")"})
  local cmd = ''
  if kind == "backtrace" then
    cmd = self.backend:translate_command('bt')
  elseif kind == "breakpoints" then
    cmd = self.backend:translate_command('info breakpoints')
  else
    log.warn({"Unknown lopen kind", kind})
    return
  end
  self.win:lopen(cmd, mods)
end

-- Split command output into lines for llist
-- @param cmd string @debugger command to execute
-- @return string[] @output lines
function App:get_for_llist(cmd)
  log.debug({"function App:get_for_llist(", cmd, ")"})
  local output = self:custom_command(cmd)
  local lines = {}
  for line in output:gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
  end
  return lines
end

return App
