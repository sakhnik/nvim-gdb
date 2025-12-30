-- Jump window management.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'

---@class Win jump window management
---@field private config Config resolved configuration
---@field private keymaps Keymaps dynamic keymap manager
---@field private cursor Cursor current line sign manager
---@field private client Client debugger terminal job
---@field private breakpoint Breakpoint breakpoint sign manager
---@field private jump_win number? window handle that will be displaying the current file
---@field private buffers table<number,boolean> set of opened buffers to close automatically
local Win = {}
Win.__index = Win

---Constructor
---@param config Config resolved configuration
---@param keymaps Keymaps dynamic keymap manager
---@param cursor Cursor current line sign manager
---@param client Client debugger terminal job
---@param breakpoint Breakpoint breakpoint sign manager
---@param start_win number? window handle that could be used as the jump window
---@param edited_buf number? buffer handle that needs to be loaded by default
---@return Win new instance
function Win.new(config, keymaps, cursor, client, breakpoint, start_win, edited_buf)
  log.debug({"Win.new", start_win = start_win, edited_buf = edited_buf})
  local self = setmetatable({}, Win)
  self.config = config
  self.keymaps = keymaps
  self.cursor = cursor
  self.client = client
  self.breakpoint = breakpoint
  self.jump_win = start_win
  self.buffers = {}  -- {buf -> true}

  self.last_jump_line = 0

  -- Create the default jump window
  self:_ensure_jump_window()

  -- The originally edited buffer may have been a new "[No Name]".
  -- The terminal buffer may be created with the same number.
  if edited_buf ~= nil and edited_buf ~= client:get_client_buf() then
    -- Load the originally edited buffer
    vim.api.nvim_win_set_buf(self.jump_win, edited_buf)
  end
  return self
end

---Only makes sense if NvimGdb.global_cleanup() is called
function Win:unset_keymaps()
  log.debug({"Win:unset_keymaps"})
  if self:_has_jump_win() then
    self:_with_saved_win(true, function()
      vim.api.nvim_set_current_win(self.jump_win)
      pcall(self.keymaps.dispatch_unset, self.keymaps)
    end)
  end
end

---Cleanup the windows and buffers.
function Win:cleanup()
  log.debug({"Win:cleanup"})
  for buf, _ in pairs(self.buffers) do
    vim.api.nvim_buf_delete(buf, {force = true})
  end
end

---Check whether the jump window is displayed.
---@return boolean true if jump window is visible
function Win:_has_jump_win()
  log.debug({"Win:_has_jump_win"})
  local wins = vim.api.nvim_tabpage_list_wins(vim.api.nvim_get_current_tabpage())
  for _, w in ipairs(wins) do
    if w == self.jump_win then
      return true
    end
  end
  return false
end

---Check whether the current buffer is displayed in the jump window.
---@return boolean
function Win:is_jump_window_active()
  log.debug({"Win:is_jump_window_active"})
  if not self:_has_jump_win() then
    return false
  end
  return vim.api.nvim_get_current_buf() == vim.api.nvim_win_get_buf(self.jump_win)
end

---Execute function and return the cursor back.
---We're going to jump to another window and return.
---There may be no need to change keymaps forth and back.
---@param dispatch_keymaps boolean true to dispatch keymaps, false if not necessary
---@param func function() action to execute
function Win:_with_saved_win(dispatch_keymaps, func)
  log.debug({"Win:_with_saved_win", dispatch_keymaps = dispatch_keymaps, func = func})
  if not dispatch_keymaps then
    self.keymaps:set_dispatch_active(false)
  end
  local prev_win = vim.api.nvim_get_current_win()
  func()
  -- The window may disappear after func()
  if pcall(vim.api.nvim_set_current_win, prev_win) then
    if not dispatch_keymaps then
      self.keymaps:set_dispatch_active(true)
    end
  end
end

---Execute function and restore the previous mode afterwards
---@param func function() action to execute
function Win:_with_saved_mode(func)
  log.debug({"Win:_with_saved_mode", func = func})
  local mode = vim.api.nvim_get_mode()
  func()
  if mode.mode:match("^[ti]$") ~= nil then
    vim.api.nvim_command("startinsert!")
  end
end

---Ensure that the jump window is available.
function Win:_ensure_jump_window()
  log.debug({"Win:_ensure_jump_window"})
  if not self:_has_jump_win() then
    -- The jump window needs to be created first
    self:_with_saved_win(false, function()
      vim.api.nvim_command(self.config:get('codewin_command'))
      self.jump_win = vim.api.nvim_get_current_win()
      -- Remember the '[No name]' buffer for later cleanup
      self.buffers[vim.api.nvim_get_current_buf()] = true
    end)
  end
end

---Ensure the scroll_off config parameter is observed in the jump window
---@param line number buffer line with the cursor
---@param scroll_off number number of the lines to keep off the window edge
function Win:_adjust_jump_win_view(line, scroll_off)
  log.debug({"Win:_adjust_jump_win_view", line = line, scroll_off = scroll_off})
  local wininfo = vim.fn.getwininfo(self.jump_win)[1]
  local botline = wininfo.botline
  local topline = wininfo.topline

  -- Try adjusting the scroll off value if the window is too low
  local win_height = botline - topline
  local max_scroll_off = (win_height - win_height % 2) / 2
  if max_scroll_off < scroll_off then
    scroll_off = max_scroll_off
  end

  if botline - topline <= scroll_off then
    return
  end

  -- Check for potential scroll off adjustments
  local new_topline = topline
  -- line - topline > scroll_off
  local top_gap = line - topline
  if top_gap < scroll_off then
    new_topline = new_topline - scroll_off + top_gap
  end

  -- botline - line > scroll_off
  local bottom_gap = botline - line
  if bottom_gap < scroll_off then
    new_topline = new_topline + scroll_off - (botline - line)
  end
  if new_topline < 1 then
    new_topline = 1
  end

  if new_topline ~= topline then
    vim.fn.winrestview({topline = new_topline})
  end
end

---Show the file and the current line in the jump window.
---@param file string full path to the source code
---@param line number line number
function Win:jump(file, line)
  log.info({"Win:jump", file = file, line = line})
  -- Check whether the file is already loaded or load it
  local target_buf = vim.fn.bufnr(file, 1)

  -- Ensure the jump window is available
  self:_with_saved_mode(function()
    self:_ensure_jump_window()
  end)

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
  self:_with_saved_win(false, function()
    vim.api.nvim_command(string.format("noa call nvim_set_current_win(%d)", self.jump_win))

    -- If there is no required file or it has fewer lines, avoid settings cursor
    -- below the last line
    local max_line = vim.fn.line('$', self.jump_win)
    if line > max_line then
      line = max_line
    end

    -- Debounce jumping because of asynchronous querying
    if line ~= self.last_jump_line then
      vim.api.nvim_win_set_cursor(self.jump_win, {line, 0})
      self.last_jump_line = line
    end

    self.cursor:set(target_buf, line)
    self.cursor:show()

    -- &scrolloff seems to have effect only in the interactive mode.
    -- So we'll have to adjust the view manually.
    local scroll_off = self.config:get_or('set_scroll_off', 1)
    self:_adjust_jump_win_view(line, scroll_off)
    vim.api.nvim_command("normal! zv")
  end)
  vim.api.nvim_command("redraw")
end

---Test whether an item is in the list
---@param it any needle
---@param list any[] haystack
---@return boolean
local function contains(it, list)
  for _, i in ipairs(list) do
    if i == it then
      return true
    end
  end
  return false
end

---@param cmd string vim command to execute
---@return number newly opened buffer handle
function Win:_open_file(cmd)
  log.debug({"Win:_open_file", cmd = cmd})
  local open_buffers = vim.api.nvim_list_bufs()
  vim.api.nvim_command(cmd)
  local new_buffer = vim.api.nvim_get_current_buf()
  if not contains(new_buffer, open_buffers) then
    -- A new buffer was open specifically for debugging,
    -- remember it to close later.
    self.buffers[new_buffer] = true
  end
  return new_buffer
end

---Show actual breakpoints in the current window.
---@async
function Win:query_breakpoints()
  log.debug({"Win:query_breakpoints"})
  -- Just notify the client that the breakpoints are being queried
  self.client:mark_has_interacted()

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
    vim.api.nvim_command("redraw")
  end
end

---Populate the location list with the result of debugger cmd.
---@param cmd string debugger command to execute
---@param mods string command modifiers like 'leftabove'
function Win:lopen(cmd, mods)
  log.debug({"Win:lopen", cmd = cmd, mods = mods})
  coroutine.resume(coroutine.create(function()
    local llist = NvimGdb.here:get_for_llist(cmd)
    self:_with_saved_mode(function()
      self:_with_saved_win(false, function()
        self:_ensure_jump_window()
        vim.api.nvim_win_call(self.jump_win, function()
          log.debug({win = self.jump_win, valid = vim.api.nvim_win_is_valid(self.jump_win), llist = llist})
          local res = vim.fn.setloclist(0, {}, ' ', {lines = llist})
          log.debug({res = res, loclist = vim.fn.getloclist(0, {lines = 1})})
          vim.cmd(mods .. ' lopen')
          log.debug({win = vim.api.nvim_get_current_win(), loclist = vim.fn.getloclist(vim.api.nvim_get_current_win())})
        end)
      end)
    end)
  end))
end

return Win
