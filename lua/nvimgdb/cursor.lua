-- Manipulating the current line sign.
-- vim:sw=2 ts=2 et

local C = {}
C.__index = C

function C.new(config)
  local self = setmetatable({}, C)
  self.config = config
  self.buf = -1
  self.line = -1
  self.sign_id = -1
  return self
end

function C.hide(self)
  -- Hide the current line sign.
  if self.sign_id ~= -1 and self.buf ~= -1 then
    vim.fn.sign_unplace('NvimGdb', {['id'] = self.sign_id, ['buffer'] = self.buf})
    self.sign_id = -1
  end
end

function C.show(self)
  -- Show the current line sign.
  -- To avoid flicker when removing/adding the sign column(due to
  -- the change in line width), we switch ids for the line sign
  -- and only remove the old line sign after marking the new one.
  local old_sign_id = self.sign_id
  if old_sign_id == -1 or old_sign_id == 4998 then
    self.sign_id = 4999
  else
    self.sign_id = 4998
  end
  if self.line ~= -1 and self.buf ~= -1 then
    local priority = self.config:get('sign_breakpoint_priority') + 1
    vim.fn.sign_place(self.sign_id, 'NvimGdb', 'GdbCurrentLine', self.buf,
      {['lnum'] = self.line, ['priority'] = priority})
  end
  if old_sign_id ~= -1 then
    vim.fn.sign_unplace('NvimGdb', {['id'] = old_sign_id, ['buffer'] = self.buf})
  end
end

function C.set(self, buf, line)
  -- Set the current line sign number.
  self.buf = buf
  self.line = tonumber(line)
end

return C
