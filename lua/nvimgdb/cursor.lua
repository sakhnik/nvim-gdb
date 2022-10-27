-- Manipulating the current line sign.
-- vim: set et sw=2 ts=2:

local log = require 'nvimgdb.log'

-- @class Cursor @current line handler
-- @field private config Config @resolved configuration
-- @field private buf number @buffer number
-- @field private line number @line number
-- @field private sign_id number @sign identifier
local Cursor = {}
Cursor.__index = Cursor

-- Constructor
-- @param config Config @resolved configuration
-- @return Cursor @new instance
function Cursor.new(config)
  log.debug({"function Cursor.new(", config, ")"})
  local self = setmetatable({}, Cursor)
  self.config = config
  self.buf = -1
  self.line = -1
  self.sign_id = -1
  return self
end

-- Hide the current line sign
function Cursor:hide()
  log.debug({"function Cursor:hide()"})
  if self.sign_id ~= -1 and self.buf ~= -1 then
    vim.fn.sign_unplace('NvimGdb', {id = self.sign_id, buffer = self.buf})
    self.sign_id = -1
  end
end

-- Show the current line sign
function Cursor:show()
  log.debug({"function Cursor:show()"})
  -- To avoid flicker when removing/adding the sign column(due to
  -- the change in line width), we switch ids for the line sign
  -- and only remove the old line sign after marking the new one.
  local old_sign_id = self.sign_id
  if old_sign_id == -1 or old_sign_id == 4998 then
    self.sign_id = 4999
  else
    self.sign_id = 4998
  end
  if self.buf ~= -1 then
    if self.line ~= -1 then
      local priority = self.config:get('sign_breakpoint_priority') + 1
      vim.fn.sign_place(self.sign_id, 'NvimGdb', 'GdbCurrentLine', self.buf,
        {lnum = self.line, priority = priority})
    end
    if old_sign_id ~= -1 then
      vim.fn.sign_unplace('NvimGdb', {id = old_sign_id, buffer = self.buf})
    end
  end
end

-- Set the current line sign number.
-- @param buf number @buffer number
-- @param line number|string @line number
function Cursor:set(buf, line)
  log.debug({"function Cursor:set(", buf, line, ")"})
  self.buf = buf
  self.line = tonumber(line)
end

return Cursor
