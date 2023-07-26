-- Manipulate keymaps: define and undefined when needed.
-- vim: set et sw=2 ts=2:

local log = require 'nvimgdb.log'

---@class Keymaps @dynamic keymaps manager
---@field private config Config supplied configuration
local Keymaps = {}
Keymaps.__index = Keymaps

---@param config Config resolved configuration
---@return Keymaps new instance of Keymaps
function Keymaps.new(config)
  log.debug({"Keymaps.new"})
  local self = setmetatable({}, Keymaps)
  self.config = config
  self.dispatch_active = true
  return self
end

---Turn on/off keymaps manipulation.
---@param state boolean true to enable keymaps dispatching, false to supress
function Keymaps:set_dispatch_active(state)
  log.debug({"Keymaps:set_dispatch_active", state = state})
  self.dispatch_active = state
end

local default = {
  { mode = 'n', term = false, key = 'key_until',      cmd = ':GdbUntil'            },
  { mode = 'n', term = true,  key = 'key_continue',   cmd = ':GdbContinue'         },
  { mode = 'n', term = true,  key = 'key_next',       cmd = ':GdbNext'             },
  { mode = 'n', term = true,  key = 'key_step',       cmd = ':GdbStep'             },
  { mode = 'n', term = true,  key = 'key_finish',     cmd = ':GdbFinish'           },
  { mode = 'n', term = false, key = 'key_breakpoint', cmd = ':GdbBreakpointToggle' },
  { mode = 'n', term = true,  key = 'key_frameup',    cmd = ':GdbFrameUp'          },
  { mode = 'n', term = true,  key = 'key_framedown',  cmd = ':GdbFrameDown'        },
  { mode = 'n', term = false, key = 'key_eval',       cmd = ':GdbEvalWord'         },
  { mode = 'v', term = false, key = 'key_eval',       cmd = ':GdbEvalRange'        },
  { mode = 'n', term = true,  key = 'key_quit',       cmd = ':GdbDebugStop'        },
}

---Define buffer-local keymaps for the jump window
function Keymaps:set()
  log.debug({"Keymaps:set"})
  -- Terminal keymaps are only set once per session, so there's
  -- no need to unset them properly (no `is_term` in Keymaps:unset()).
  local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local is_term = bufname:match("^term://") ~= nil
  for _, m in ipairs(default) do
    local keystroke = self.config:get(m.key)
    if keystroke ~= nil then
      if not is_term or m.term then
        vim.api.nvim_buf_set_keymap(vim.api.nvim_get_current_buf(), m.mode,
          keystroke, m.cmd .. '<cr>', {silent = true})
      end
    end
  end
end

---Undefine buffer-local keymaps for the jump window
function Keymaps:unset()
  log.debug({"Keymaps:unset"})
  for _, m in ipairs(default) do
    local keystroke = self.config:get(m.key)
    if keystroke ~= nil then
      pcall(vim.api.nvim_buf_del_keymap, vim.api.nvim_get_current_buf(), m.mode, keystroke)
    end
  end
end

local default_t = {
  { key = 'key_until',    cmd = ':GdbUntil'     },
  { key = 'key_continue', cmd = ':GdbContinue'  },
  { key = 'key_next',     cmd = ':GdbNext'      },
  { key = 'key_step',     cmd = ':GdbStep'      },
  { key = 'key_finish',   cmd = ':GdbFinish'    },
  { key = 'key_quit',     cmd = ':GdbDebugStop' },
}

---Define term-local keymaps.
function Keymaps:set_t()
  log.debug({"Keymaps:set_t"})
  for _, m in ipairs(default_t) do
    local keystroke = self.config:get(m.key)
    if keystroke ~= nil then
      vim.api.nvim_buf_set_keymap(vim.api.nvim_get_current_buf(), 't',
        keystroke, [[<c-\><c-n>]] .. m.cmd .. [[<cr>i]], {silent = true})
    end
  end
  vim.api.nvim_buf_set_keymap(vim.api.nvim_get_current_buf(), 't',
    '<esc>', [[<c-\><c-n>G]], {silent = true})
end

---Run by the configuration and call the appropriate keymap handler
---@param key string keymap routine like set_keymaps
function Keymaps:_dispatch(key)
  log.debug({"Keymaps:_dispatch", key = key})
  if self.dispatch_active then
    self.config:get_or(key, function(_) end)(self)
  end
end

---Call the hook to set the keymaps.
function Keymaps:dispatch_set()
  log.debug({"Keymaps:dispatch_set"})
  self:_dispatch 'set_keymaps'
end

---Call the hook to unset the keymaps.
function Keymaps:dispatch_unset()
  log.debug({"Keymaps:dispatch_unset"})
  self:_dispatch 'unset_keymaps'
end

---Call the hook to set the terminal keymaps.
function Keymaps:dispatch_set_t()
  log.debug({"Keymaps:dispatch_set_t"})
  self:_dispatch 'set_tkeymaps'
end

return Keymaps
