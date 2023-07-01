-- LLDB specifics
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local Common = require'nvimgdb.backend.common'
local ParserImpl = require'nvimgdb.parser_impl'
local utils = require'nvimgdb.utils'

-- @class BackendLldb:Backend @specifics of LLDB
local C = {}
C.__index = C
setmetatable(C, {__index = Common})

-- @return BackendLldb @new instance
function C.new()
  local self = setmetatable({}, C)
  return self
end

-- Create a parser to recognize state changes and code jumps
-- @param actions ParserActions @callbacks for the parser
-- @param proxy Proxy @side channel connection to the debugger
-- @return ParserImpl @new parser instance
function C.create_parser(actions, proxy)
  local P = {}
  P.__index = P
  setmetatable(P, {__index = ParserImpl})

  local self = setmetatable({}, P)
  self:_init(actions)

  function P:query_paused()
    local location = proxy:query('get-current-frame-location')
    log.debug({"current frame location", location})
    if #location == 2 then
      local fname = location[1]
      local line = location[2]
      self.actions:jump_to_source(fname, line)
    end
    self.actions:query_breakpoints()
    return self.paused
  end

  local re_prompt = '%s%(lldb%) %(lldb%) $'
  if utils.is_windows then
    re_prompt = '%(lldb%) *$'
  end
  self.add_trans(self.paused, 'Process %d+ resuming', self._paused_continue)
  self.add_trans(self.paused, 'Process %d+ launched', self._paused_continue)
  self.add_trans(self.paused, 'Process %d+ exited', self._paused_continue)
  self.add_trans(self.paused, re_prompt, self.query_paused)
  self.add_trans(self.running, 'Process %d+ stopped', self._paused)
  self.add_trans(self.running, re_prompt, self.query_paused)

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
  delete_breakpoints = 'breakpoint delete',
  breakpoint = 'b',
  ['until %s'] = 'thread until %s',
  ['info breakpoints'] = 'nvim-gdb-info-breakpoints',
}

-- @return string[]
function C.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  -- Breakpoint list is queried specifically with a custom command
  -- nvim-gdb-info-breakpoints, which is only implemented in the proxy.
  return {[[%m\ at\ %f:%l]], [[%f:%l\ %m]]}
end

-- @param client_cmd string[] @original debugger command
-- @param tmp_dir string @path to the session state directory
-- @param proxy_addr string @full path to the file with the udp port in the session state directory
-- @return string[] @command to launch the debugger with termopen()
function C.get_launch_cmd(client_cmd, tmp_dir, proxy_addr)

  -- Assuming the first argument is path to lldb, the rest are arguments.
  -- We'd like to ensure gdb is launched with our custom initialization
  -- injected.

  local lldb = client_cmd[1]

  local lldb_init = utils.path_join(tmp_dir, "lldb_init")
  local file = io.open(lldb_init, "w")
  assert(file, "Failed to open lldb_init for writing")
  if file then
    if utils.is_windows then
      -- Change code page to UTF-8 in Windows, required to avoid distortion of characters like \x1a (^Z)
      file:write("shell chcp 65001\n")
    end
    file:write("settings set auto-confirm true\n")
    file:write("settings set stop-line-count-before 0\n")
    file:write("settings set stop-line-count-after 0\n")
    file:write([[settings set frame-format frame #${frame.index}: ${frame.pc}{ ${module.file.basename}{\`${function.name-with-args}{${frame.no-debug}${function.pc-offset}}}}{ at \032\032${line.file.fullpath}:${line.number}}{${function.is-optimized} [opt]}\n]])
    file:write("\n")
    file:write("command script import " .. utils.get_plugin_file_path("lib", "lldb_commands.py") .. "\n")
    file:write("command script add -f lldb_commands.init nvim-gdb-init\n")
    file:write("nvim-gdb-init " .. proxy_addr .. "\n")
    file:close()
  end

  -- Execute lldb finally with our custom initialization script
  local cmd = {lldb, '-S', lldb_init}
  -- Append the rest of arguments
  for i = 2, #client_cmd do
    cmd[#cmd + 1] = client_cmd[i]
  end
  return cmd
end

return C
