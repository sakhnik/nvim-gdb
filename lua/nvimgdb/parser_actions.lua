-- Common FSM implementation for the integrated backends.
-- vim: set et ts=2 sw=2:

local log = require 'nvimgdb.log'

---@class ParserActions @parser callbacks handler
---@field private cursor Cursor @current line sign handler
---@field private win Win @jump window manager
local ParserActions = {}
ParserActions.__index = ParserActions

---Constructor
---@param cursor Cursor
---@param win Win
---@return ParserActions
function ParserActions.new(cursor, win)
  log.debug({"ParserActions.new"})
  local self = setmetatable({}, ParserActions)
  self.cursor = cursor
  self.win = win
  return self
end

---Handle the program continued execution. Hide the cursor.
function ParserActions:continue_program()
  log.debug({"ParserActions:continue_program"})
  self.cursor:hide()
  vim.api.nvim_command("doautocmd User NvimGdbContinue")
end

---Handle the program breaked. Show the source code.
---@param fname string full path to the source file
---@param line number line number
function ParserActions:jump_to_source(fname, line)
  log.debug({"ParserActions:jump_to_source", fname = fname, line = line})
  self.win:jump(fname, line)
  vim.api.nvim_command("doautocmd User NvimGdbBreak")
end

---It's high time to query actual breakpoints.
function ParserActions:query_breakpoints()
  log.debug({"ParserActions:query_breakpoints"})
  self.win:query_breakpoints()
  -- Execute the rest of custom commands
  vim.api.nvim_command("doautocmd User NvimGdbQuery")
end

return ParserActions
