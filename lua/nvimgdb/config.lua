-- Handle configuration settings
-- vim: et sw=2 ts=2:

local Keymaps = require 'nvimgdb.keymaps'

local C = {}
C.__index = C

-- Default configuration
local default = {
  ['key_until']           = '<f4>',
  ['key_continue']        = '<f5>',
  ['key_next']            = '<f10>',
  ['key_step']            = '<f11>',
  ['key_finish']          = '<f12>',
  ['key_breakpoint']      = '<f8>',
  ['key_frameup']         = '<c-p>',
  ['key_framedown']       = '<c-n>',
  ['key_eval']            = '<f9>',
  ['key_quit']            = nil,
  ['set_tkeymaps']        = Keymaps.set_t,
  ['set_keymaps']         = Keymaps.set,
  ['unset_keymaps']       = Keymaps.unset,
  ['sign_current_line']   = '▶',
  ['sign_breakpoint']     = {'●', '●²', '●³', '●⁴', '●⁵', '●⁶', '●⁷', '●⁸', '●⁹', '●ⁿ'},
  ['sign_breakpoint_priority'] = 10,
  ['codewin_command']     = 'new',
  ['set_scroll_off']      = 5,
}

-- Turn a string into a funcref looking up a Vim function.
local function filter_funcref(key, val)
  -- Lookup the key in the default config.
  local def_val = default[key]
  -- Check whether the key should be a function.
  if type(def_val) ~= "function" then
    return val
  end
  -- Finally, turn the value into a Vim function call.
  return function(_) vim.call(val) end
end

local function copy_user_config()
  -- Make a copy of the supplied configuration if defined
  local config = vim.g.nvimgdb_config
  if config == nil then
    return nil
  end

  for key, val in pairs(config) do
    local filtered_val = filter_funcref(key, val)
    if filtered_val ~= nil then
      config[key] = filtered_val
    end
  end

  -- Make sure the essential keys are present even if not supplied.
  for _, must_have in pairs({'sign_current_line', 'sign_breakpoint',
    'codewin_command', 'set_scroll_off'}) do
    if config[must_have] == nil then
      config[must_have] = default[must_have]
    end
  end

  return config
end

function C.new()
  local self = setmetatable({}, C)
  -- Prepare actual configuration with overrides resolved.
  self.key_to_func = {}

  -- Make a copy of the supplied configuration if defined
  self.config = copy_user_config()
  if self.config == nil then
    self.config = {}
    for key, val in pairs(default) do
      self.config[key] = val
    end
  end

  for func, key in pairs(self.config) do
    self:_check_keymap_conflicts(key, func, true)
  end

  self:_apply_overrides()
  self:_define_signs()
  return self
end

function C._apply_overrides(self)
  -- If there is config override defined, add it
  local override = vim.g.nvimgdb_config_override
  if override ~= nil then
    for key, val in pairs(override) do
      local key_val = filter_funcref(key, val)
      if key_val ~= nil then
        self:_check_keymap_conflicts(key_val, key, true)
        self.config[key] = key_val
      end
    end
  end

  -- See whether a global override for a specific configuration
  -- key exists. If so, update the config.
  for key, _ in pairs(default) do
    local val = loadstring('return vim.g.nvimgdb_' .. key)()
    if val ~= nil then
      local key_val = filter_funcref(key, val)
      if key_val ~= nil then
        self:_check_keymap_conflicts(key_val, key, false)
        self.config[key] = key_val
      end
    end
  end
end

function C:_check_keymap_conflicts(key, func, verbose)
  -- Check for keymap configuration sanity.
  if func:match('^key_.*') ~= nil then
    local prev_func = self.key_to_func[key]
    if prev_func ~= nil and prev_func ~= func then
      if verbose then
        print('Overriding conflicting keymap "' .. key .. '" for '
          .. func .. ' (was ' .. prev_func .. ')')
      end
      self.key_to_func[self.config[func]] = nil
      self.config[prev_func] = nil
    end
    self.key_to_func[key] = func
  end
end

function C._define_signs(self)
  -- Define the sign for current line the debugged program is executing.
  vim.fn.sign_define('GdbCurrentLine', {['text'] = self.config.sign_current_line})
  -- Define signs for the breakpoints.
  for i, brk in ipairs(self.config.sign_breakpoint) do
    vim.fn.sign_define('GdbBreakpoint' .. i, {['text'] = brk})
  end
end

function C:get(key)
  return self.config[key]
end

-- Get the configuration value by key or return the val if missing.
function C:get_or(key, val)
  local v = self:get(key)
  if v == nil then v = val end
  return v
end

return C
