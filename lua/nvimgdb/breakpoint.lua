-- Handle breakpoint signs.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'

local C = {}
C.__index = C

function C.new(config, proxy, query_impl)
  local self = setmetatable({}, C)
  self.config = config
  self.proxy = proxy
  -- Backend implementation of breakpoint query
  self.query_impl = query_impl
  -- Discovered breakpoints so far: {file -> {line -> [id]}}
  self.breaks = {}
  self.max_sign_id = 0
  return self
end

function C:clear_signs()
  -- Clear all breakpoint signs.
  for i = 5000, self.max_sign_id do
    vim.fn.sign_unplace('NvimGdb', {id = i})
  end
  self.max_sign_id = 0
end

function C:_set_signs(buf)
  if buf ~= -1 then
    local sign_id = 5000 - 1
    -- Breakpoints need full path to the buffer (at least in lldb)
    local bpath = vim.fn.expand('#' .. tostring(buf) .. ':p')

    local function _get_sign_name(idx)
      local max_count = #self.config:get('sign_breakpoint')
      if idx > max_count then
        idx = max_count
      end
      return "GdbBreakpoint" .. tostring(idx)
    end

    local priority = self.config:get('sign_breakpoint_priority')
    local for_file = self.breaks[bpath]
    if for_file ~= nil then
      for line, ids in pairs(for_file) do
        sign_id = sign_id + 1
        local sign_name = _get_sign_name(#ids)
        vim.fn.sign_place(sign_id, 'NvimGdb', sign_name, buf,
                      {lnum = line, priority = priority})
      end
      self.max_sign_id = sign_id
    end
  end
end

-- Query actual breakpoints for the given file.
function C:query(buf_num, fname)
  log.info("Query breakpoints for " .. fname)
  self.breaks[fname] = self.query_impl(fname, self.proxy)
  self:clear_signs()
  self:_set_signs(buf_num)
end

-- Reset all known breakpoints and their signs.
function C:reset_signs()
  self.breaks = {}
  self:clear_signs()
end

-- Get breakpoints for the given position in a file.
function C:get_for_file(fname, line)
  local breaks = self.breaks[fname]
  if breaks == nil then
    return {}
  end
  local ids = breaks[tostring(line)]   -- make sure the line is a string
  if ids == nil then
    return {}
  end
  return ids
end

return C
