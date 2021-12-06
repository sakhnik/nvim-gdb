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

-- Define buffer-local keymaps for the jump window
function C:set()
  -- Terminal keymaps are only set once per session, so there's
  -- no need to unset them properly (no `is_term` in C:unset()).
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

-- Undefine buffer-local keymaps for the jump window
function C:unset()
  for _, m in ipairs(default) do
    local keystroke = self.config:get(m.key)
    if keystroke ~= nil then
      vim.api.nvim_buf_del_keymap(vim.api.nvim_get_current_buf(), m.mode, keystroke)
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

-- Define term-local keymaps.
function C:set_t()
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
