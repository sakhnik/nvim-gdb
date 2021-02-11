-- Manipulate keymaps: define and undefined when needed.
-- vim: set et sw=2 ts=2:

-- @class Keymaps @dynamic keymaps manager
-- @field private config Config @supplied configuration
local C = {}
C.__index = C

-- @param config Config @resolved configuration
-- @return Keymaps @new instance of Keymaps
function C.new(config)
  local self = setmetatable({}, C)
  self.config = config
  self.dispatch_active = true
  return self
end

-- Turn on/off keymaps manipulation.
-- @param state boolean @true to enable keymaps dispatching, false to supress
function C:set_dispatch_active(state)
  self.dispatch_active = state
end

local default = {
  {'n', 'key_until', ':GdbUntil'},
  {'n', 'key_continue', ':GdbContinue'},
  {'n', 'key_next', ':GdbNext'},
  {'n', 'key_step', ':GdbStep'},
  {'n', 'key_finish', ':GdbFinish'},
  {'n', 'key_breakpoint', ':GdbBreakpointToggle'},
  {'n', 'key_frameup', ':GdbFrameUp'},
  {'n', 'key_framedown', ':GdbFrameDown'},
  {'n', 'key_eval', ':GdbEvalWord'},
  {'v', 'key_eval', ':GdbEvalRange'},
  {'n', 'key_quit', ':GdbDebugStop'},
}

-- Define buffer-local keymaps for the jump window
function C:set()
  for _, tuple in ipairs(default) do
    local mode, key, cmd = unpack(tuple)
    local keystroke = self.config:get(key)
    if keystroke ~= nil then
      vim.api.nvim_buf_set_keymap(vim.api.nvim_get_current_buf(), mode,
        keystroke, cmd .. '<cr>', {silent = true})
    end
  end
end

-- Undefine buffer-local keymaps for the jump window
function C:unset()
  for _, tuple in ipairs(default) do
    local mode, key = unpack(tuple)
    local keystroke = self.config:get(key)
    if keystroke ~= nil then
      vim.api.nvim_buf_del_keymap(vim.api.nvim_get_current_buf(), mode, keystroke)
    end
  end
end

local default_t = {
  {'key_until', ':GdbUntil'},
  {'key_continue', ':GdbContinue'},
  {'key_next', ':GdbNext'},
  {'key_step', ':GdbStep'},
  {'key_finish', ':GdbFinish'},
  {'key_quit', ':GdbDebugStop'},
}

-- Define term-local keymaps.
function C:set_t()
  for _, tuple in ipairs(default_t) do
    local key, cmd = unpack(tuple)
    local keystroke = self.config:get(key)
    if keystroke ~= nil then
      vim.api.nvim_buf_set_keymap(vim.api.nvim_get_current_buf(), 't',
        keystroke, [[<c-\><c-n>]] .. cmd .. [[<cr>i]], {silent = true})
    end
  end
  vim.api.nvim_buf_set_keymap(vim.api.nvim_get_current_buf(), 't',
    '<esc>', [[<c-\><c-n>G]], {silent = true})
end

-- Run by the configuration and call the appropriate keymap handler
-- @param key string @keymap routine like set_keymaps
function C:_dispatch(key)
  if self.dispatch_active then
    self.config:get_or(key, function(_) end)(self)
  end
end

-- Call the hook to set the keymaps.
function C:dispatch_set()
  self:_dispatch 'set_keymaps'
end

-- Call the hook to unset the keymaps.
function C:dispatch_unset()
  self:_dispatch 'unset_keymaps'
end

-- Call the hook to set the terminal keymaps.
function C:dispatch_set_t()
  self:_dispatch 'set_tkeymaps'
end

return C
