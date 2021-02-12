-- Common FSM implementation for the integrated backends.
-- vim: set et ts=2 sw=2:

-- @class ParserActions @parser callbacks handler
-- @field private cursor Cursor @current line sign handler
local C = {}
C.__index = C

function C.new(cursor, win)
  local self = setmetatable({}, C)
  self.cursor = cursor
  self.win = win
  return self
end

-- Handle the program continued execution. Hide the cursor.
function C:continue_program()
  self.cursor:hide()
  vim.cmd("doautocmd User NvimGdbContinue")
end

-- Handle the program breaked. Show the source code.
function C:jump_to_source(fname, line)
  self.win:jump(fname, line)
  vim.cmd("doautocmd User NvimGdbBreak")
end

-- It's high time to query actual breakpoints.
function C:query_breakpoints()
  self.win:query_breakpoints()
  -- Execute the rest of custom commands
  vim.cmd("doautocmd User NvimGdbQuery")
end

return C
