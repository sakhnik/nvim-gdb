-- GDB specifics
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local Common = require'nvimgdb.backend.common'
local ParserImpl = require'nvimgdb.parser_impl'
local utils = require'nvimgdb.utils'

-- @class BackendGdb:Backend @specifics of GDB
local C = {}
C.__index = C
setmetatable(C, {__index = Common})

-- @return BackendGdb @new instance
function C.new()
  local self = setmetatable({}, C)
  return self
end

-- Create a parser to recognize state changes and code jumps
-- @param actions ParserActions @callbacks for the parser
-- @return ParserImpl @new parser instance
function C.create_parser(actions)
  local P = {}
  P.__index = P
  setmetatable(P, {__index = ParserImpl})

  local self = setmetatable({}, P)
  self:_init(actions)

  local re_prompt = '%(gdb%) \x1a\x1a\x1a'
  local re_jump = '[\r\n]\x1a\x1a([A-Z]*:*[^:]+):(%d+):%d+'
  self.add_trans(self.paused, '[\r\n]Continuing%.', self._paused_continue)
  self.add_trans(self.paused, '[\r\n]Starting program:', self._paused_continue)
  self.add_trans(self.paused, re_jump, self._paused_jump)
  self.add_trans(self.paused, re_prompt, self._query_b)
  self.add_trans(self.running, '%sBreakpoint %d+', self._query_b)
  self.add_trans(self.running, '%sTemporary breakpoint %d+', self._query_b)
  self.add_trans(self.running, re_jump, self._paused_jump)
  self.add_trans(self.running, re_prompt, self._query_b)

  self.state = self.running

  return self
end

-- @param fname string @full path to the source
-- @param proxy Proxy @connection to the side channel
-- @return FileBreakpoints @collection of actual breakpoints
function C.query_breakpoints(fname, proxy)
  log.info("Query breakpoints for " .. fname)
  local breaks = proxy:query('info-breakpoints ' .. fname)
  if breaks == nil or next(breaks) == nil then
    return {}
  end
  -- We expect the proxies to send breakpoints for a given file
  -- as a map of lines to array of breakpoint ids set in those lines.
  local err = breaks._error
  if err ~= nil then
    log.error("Can't get breakpoints: " .. err)
    return {}
  end
  return breaks
end

-- @type CommandMap
C.command_map = {
  delete_breakpoints = 'delete',
  breakpoint = 'break',
  ['info breakpoints'] = 'info breakpoints',
}

-- @return string[]
function C.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  return {[[%m\ at\ %f:%l]], [[%m\ %f:%l]]}
end

-- @param client_cmd string[] @original debugger command
-- @param tmp_dir string @path to the session state directory
-- @param proxy_addr string @full path to the file with the udp port in the session state directory
-- @return string[] @command to launch the debugger with termopen()
function C.get_launch_cmd(client_cmd, tmp_dir, proxy_addr)

  -- Assuming the first argument is path to gdb, the rest are arguments.
  -- We'd like to ensure gdb is launched with our custom initialization
  -- injected.

  -- Check for rr-replay.py
  local gdb = client_cmd[1]
  if gdb == "rr-replay.py" then
    gdb = utils.get_plugin_file_path("lib", "rr-replay.py")
  end

  local gdb_init = utils.path_join(tmp_dir, "gdb_init")
  local file = io.open(gdb_init, "w")
  assert(file, "Failed to open gdb_init for writing")
  if file then
    file:write([[
set confirm off
set pagination off
set filename-display absolute
python gdb.prompt_hook = lambda p: p + ("" if p.endswith("\x01\x1a\x1a\x1a\x02") else "\x01\x1a\x1a\x1a\x02")
]])
    file:write("source " .. utils.get_plugin_file_path("lib", "gdb_commands.py") .. "\n")
    file:write("nvim-gdb-init " .. proxy_addr .. "\n")
    if utils.is_windows() then
      -- Change code page to UTF-8 in Windows, required to avoid distortion of characters like \x1a (^Z)
      file:write("!chcp 65001\n")
    end
    file:close()
  end

  local cmd = {gdb, '-f', '-ix', gdb_init}
  -- Append the rest of arguments
  for i = 2, #client_cmd do
    cmd[#cmd + 1] = client_cmd[i]
  end
  return cmd
end

return C
