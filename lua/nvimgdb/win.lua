-- Jump window management.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'

-- @class Win @jump window management
-- @field private config Config @resolved configuration
-- @field private keymaps Keymaps @dynamic keymap manager
-- @field private cursor Cursor @current line sign manager
-- @field private client Client @debugger terminal job
-- @field private breakpoint Breakpoint @breakpoint sign manager
-- @field private jump_win number @window number that will be displaying the current file
-- @field private buffers table<number,boolean> @set of opened buffers to close automatically
local C = {}
C.__index = C

-- Constructor
-- @param config Config @resolved configuration
-- @param keymaps Keymaps @dynamic keymap manager
-- @param cursor Cursor @current line sign manager
-- @param client Client @debugger terminal job
-- @param breakpoint Breakpoint @breakpoint sign manager
-- @return Win @new instance
function C.new(config, keymaps, cursor, client, breakpoint)
  local self = setmetatable({}, C)
  self.config = config
  self.keymaps = keymaps
  self.cursor = cursor
  self.client = client
  self.breakpoint = breakpoint
  self.jump_win = nil
  self.buffers = {}  -- {buf -> true}

  -- Create the default jump window
  self:_ensure_jump_window()
  return self
end

-- Cleanup the windows and buffers.
function C:cleanup()
  for buf, _ in pairs(self.buffers) do
    vim.api.nvim_buf_delete(buf, {})
  end
end

-- Check whether the jump window is displayed.
-- @return boolean @true if jump window is visible
function C:_has_jump_win()
  local wins = vim.api.nvim_tabpage_list_wins(vim.api.nvim_get_current_tabpage())
  for _, w in ipairs(wins) do
    if w == self.jump_win then
      return true
    end
  end
  return false
end

-- Check whether the current buffer is displayed in the jump window.
-- @return boolean
function C:is_jump_window_active()
  if not self:_has_jump_win() then
    return false
  end
  return vim.api.nvim_get_current_buf() == vim.api.nvim_win_get_buf(self.jump_win)
end

-- Execute function and return the cursor back.
-- We're going to jump to another window and return.
-- There may be no need to change keymaps forth and back.
-- @param dispatch_keymaps boolean @true to dispatch keymaps, false if not necessary
-- @param func fun() @action to execute
function C:_with_saved_win(dispatch_keymaps, func)
  if not dispatch_keymaps then
    self.keymaps:set_dispatch_active(false)
  end
  local prev_win = vim.api.nvim_get_current_win()
  func()
  vim.api.nvim_set_current_win(prev_win)
  if not dispatch_keymaps then
    self.keymaps:set_dispatch_active(true)
  end
end

-- Execute function and restore the previous mode afterwards
-- @param func fun() @action to execute
function C:_with_saved_mode(func)
  local mode = vim.api.nvim_get_mode()
  func()
  if mode.mode:match("[ti]") ~= nil then
    vim.cmd("startinsert!")
  end
end

-- Ensure that the jump window is available.
function C:_ensure_jump_window()
  if not self:_has_jump_win() then
    -- The jump window needs to be created first
    self:_with_saved_win(false, function()
      vim.cmd(self.config:get('codewin_command'))
      self.jump_win = vim.api.nvim_get_current_win()
      -- Remember the '[No name]' buffer for later cleanup
      self.buffers[vim.api.nvim_get_current_buf()] = true
    end)
  end
end

-- Show the file and the current line in the jump window.
-- @param file string @full path to the source code
-- @param line number|string @line number
function C:jump(file, line)
  log.info("jump(" .. file .. ":" .. line .. ")")
  -- Check whether the file is already loaded or load it
  local target_buf = vim.fn.bufnr(file, 1)

  -- Ensure the jump window is available
  self:_with_saved_mode(function()
    self:_ensure_jump_window()
  end)
  -- TODO handle potential misconfiguration
  --if not self.jump_win:
  --    raise AssertionError("No jump window")

  -- The terminal buffer may contain the name of the source file
  -- (in pdb, for instance).
  if target_buf == self.client:get_buf() then
    self:_with_saved_win(true, function()
      vim.api.nvim_set_current_win(self.jump_win)
      target_buf = self:_open_file("noswapfile view " .. file)
    end)
  end

  if vim.api.nvim_win_get_buf(self.jump_win) ~= target_buf then
    self:_with_saved_mode(function()
      self:_with_saved_win(true, function()
        if self.jump_win ~= vim.api.nvim_get_current_win() then
          vim.api.nvim_set_current_win(self.jump_win)
        end
        -- Hide the current line sign when navigating away.
        self.cursor:hide()
        target_buf = self:_open_file("noswap e " .. file)
      end)
    end)
  end

  -- Goto the proper line and set the cursor on it
  vim.api.nvim_win_set_cursor(self.jump_win, {line, 0})
  self.cursor:set(target_buf, line)
  self.cursor:show()
  vim.cmd("redraw")
end

-- Test whether an item is in the list
-- @param it any @needle
-- @param list any[] @haystack
-- @return boolean
local function contains(it, list)
  for _, i in ipairs(list) do
    if i == it then
      return true
    end
  end
  return false
end

-- @param cmd string @vim command to execute
-- @return number @newly opened buffer handle
function C:_open_file(cmd)
  local open_buffers = vim.api.nvim_list_bufs()
  vim.cmd(cmd)
  local new_buffer = vim.api.nvim_get_current_buf()
  if not contains(new_buffer, open_buffers) then
    -- A new buffer was open specifically for debugging,
    -- remember it to close later.
    self.buffers[new_buffer] = true
  end
  return new_buffer
end

-- Show actual breakpoints in the current window.
function C:query_breakpoints()
  if not self:_has_jump_win() then
    return
  end

  -- Get the source code buffer number
  local buf_num = vim.api.nvim_win_get_buf(self.jump_win)

  -- Get the source code file name
  local fname = vim.fn.expand('#' .. buf_num .. ':p')

  -- If no file name or a weird name with spaces, ignore it (to avoid
  -- misinterpretation)
  if fname ~= '' and fname:find(' ') == nil then
    -- Query the breakpoints for the shown file
    self.breakpoint:query(buf_num, fname)
    vim.cmd("redraw")
  end
end

-- Populate the location list with the result of debugger cmd.
-- @param cmd string @debugger command to execute
-- @param mods string @command modifiers like 'leftabove'
function C:lopen(cmd, mods)
  self:_with_saved_mode(function()
    self:_with_saved_win(false, function()
      self:_ensure_jump_window()
      if self.jump_win ~= vim.api.nvim_get_current_win() then
        vim.api.nvim_set_current_win(self.jump_win)
      end
      local lgetexpr = "lgetexpr luaeval('NvimGdb.i():get_for_llist(_A[1])', ['" .. cmd .. "'])"
      vim.cmd(lgetexpr)
      vim.cmd("exe 'normal <c-o>' | " .. mods .. " lopen")
    end)
  end)
end

return C
