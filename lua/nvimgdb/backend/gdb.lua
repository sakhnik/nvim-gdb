-- GDB specifics
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local Common = require'nvimgdb.backend.common'
local ParserImpl = require'nvimgdb.parser_impl'

-- @class BackendGdb @specifics of GDB
local C = {}
C.__index = C
setmetatable(C, {__index = Common})

-- @return BackendGdb @new instance of GdbBackend
function C.new()
  local self = setmetatable({}, C)
  return self
end

-- Create a parser to recognize state changes and code jumps
-- @param actions ParserActions @callbacks for the parser
function C.create_parser(actions)
  local P = {}
  P.__index = P
  setmetatable(P, {__index = ParserImpl})

  local self = setmetatable({}, P)
  self:_init(actions)

  local re_prompt = '\x1a\x1a\x1a$'
  local re_jump = '[\r\n]\x1a\x1a([^:]+):(%d+):%d+'
  self.add_trans(self.paused, '[\r\n]Continuing%.', self._paused_continue)
  self.add_trans(self.paused, re_jump, self._paused_jump)
  self.add_trans(self.paused, re_prompt, self._query_b)
  self.add_trans(self.running, '[\r\n]Breakpoint %d+', self._query_b)
  self.add_trans(self.running, re_prompt, self._query_b)
  self.add_trans(self.running, re_jump, self._paused_jump)

  self.state = self.running

  return self
end

function C.query_breakpoints(fname, proxy)
  log.info("Query breakpoints for " .. fname)
  local response = proxy:query('handle-command info breakpoints')
  if response == nil or response == '' then
    return {}
  end

  -- Select lines in the current file with enabled breakpoints.
  local breaks = {}
  for line in response:gmatch("[^\n\r]+") do
    if line:find("%sy%s+0x") ~= nil then    -- Is enabled?
      local fields = {}
      for field in line:gmatch("[^%s]+") do
        fields[#fields+1] = field
      end
      -- file.cpp:line
      local bpfname, lnum = fields[#fields]:match("^([^:]+):(%d+)$")
      if bpfname ~= nil then
        local is_end_match = fname:sub(-#bpfname) == bpfname  -- ends with
        -- Try with the real path too
        bpfname = vim.loop.fs_realpath(bpfname)
        local is_end_match_full_path = bpfname ~= nil and fname:sub(-#bpfname) == bpfname

        if is_end_match or is_end_match_full_path then
          -- If a breakpoint has multiple locations, GDB only
          -- allows to disable by the breakpoint number, not
          -- location number.  For instance, 1.4 -> 1
          local bid = fields[1]:gmatch("[^.]+")()
          local list = breaks[lnum]
          if list == nil then
            breaks[lnum] = {bid}
          else
            list[#list + 1] = bid
          end
        end
      end
    end
  end

  return breaks
end

C.command_map = {
  delete_breakpoints = 'delete',
  breakpoint = 'break',
  ['info breakpoints'] = 'info breakpoints',
}

function C.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  return {[[%m\ at\ %f:%l]], [[%m\ %f:%l]]}
end

return C
