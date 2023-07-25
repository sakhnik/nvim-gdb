-- Handle breakpoint signs.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'

---@alias FileBreakpoints table<number, string[]>    # breakpoint collection for a file {line -> [id]}
---@alias QueryBreakpoints function(fname: string, proxy: Proxy): FileBreakpoints  # Function to obtain a breakpoint collection

---@class Breakpoint breakpoint signs handler
---@field private config Config resolved configuration
---@field private proxy Proxy connection to the side channel
---@field private query_impl QueryBreakpoints function to query breakpoints for a given file
---@field private breaks table<string, FileBreakpoints> discovered breakpoints so far: {file -> {line -> [id]}}
---@field private max_sign_id number biggest sign identifier for the breakpoints in use
local Breakpoint = {}
Breakpoint.__index = Breakpoint

---Constructor
---@param config Config resolved configuration
---@param proxy Proxy @connection to the side channel
---@param query_impl QueryBreakpoints @function to query breakpoints
---@return Breakpoint @new instance
function Breakpoint.new(config, proxy, query_impl)
  log.debug({"Breakpoint.new", config = config, proxy = proxy, query_impl = query_impl})
  local self = setmetatable({}, Breakpoint)
  self.config = config
  self.proxy = proxy
  self.query_impl = query_impl
  self.breaks = {}
  self.max_sign_id = 0
  return self
end

---Clear all breakpoint signs in all buffers
function Breakpoint:clear_signs()
  log.debug({"Breakpoint:clear_signs"})
  -- Clear all breakpoint signs.
  for i = 5000, self.max_sign_id do
    vim.fn.sign_unplace('NvimGdb', {id = i})
  end
  self.max_sign_id = 0
end

---Set a breakpoint sign in the given buffer
---@param buf number @buffer number
function Breakpoint:_set_signs(buf)
  log.debug({"Breakpoint:_set_signs", buf = buf})
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
        if type(line) == "string" then
          sign_id = sign_id + 1
          local sign_name = _get_sign_name(#ids)
          vim.fn.sign_place(sign_id, 'NvimGdb', sign_name, buf,
            {lnum = line, priority = priority})
        end
      end
      self.max_sign_id = sign_id
    end
  end
end

---Query actual breakpoints for the given file.
---@param buf_num number buffer number
---@param fname string full path to the source code file
function Breakpoint:query(buf_num, fname)
  log.info({"Breakpoint:query(", buf_num = buf_num, fname = fname})
  self.breaks[fname] = self.query_impl(fname, self.proxy)
  self:clear_signs()
  self:_set_signs(buf_num)
end

---Reset all known breakpoints and their signs.
function Breakpoint:reset_signs()
  log.debug({"Breakpoint:reset_signs"})
  self.breaks = {}
  self:clear_signs()
end

---Get breakpoints for the given position in a file.
---@param fname string full path to the source code file
---@param line number|string line number
---@return string[] list of breakpoint identifiers
function Breakpoint:get_for_file(fname, line)
  log.debug({"Breakpoint:get_for_file", fname = fname, line = line})
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

return Breakpoint
