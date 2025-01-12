-- GDB specifics
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local Backend = require'nvimgdb.backend'
local ParserImpl = require'nvimgdb.parser_impl'
local utils = require'nvimgdb.utils'

---@class BackendGdb: Backend @specifics of GDB
local C = {}
C.__index = C
setmetatable(C, {__index = Backend})

---@return BackendGdb new instance
function C.new()
  local self = setmetatable({}, C)
  return self
end

---Create a parser to recognize state changes and code jumps
---@param actions ParserActions callbacks for the parser
---@param proxy Proxy side channel connection to the debugger
---@return ParserImpl new parser instance
function C.create_parser(actions, proxy)
  local P = {}
  P.__index = P
  setmetatable(P, {__index = ParserImpl})

  local self = setmetatable({}, P)
  self:_init(actions)

  P.prev_fname = nil
  P.prev_line = nil

  function P:query_paused()
    log.debug({"P:query_paused"})
    coroutine.resume(coroutine.create(function()
      local process_state = proxy:query('get-process-state')
      log.debug({"process state", process_state})
      if process_state == 'stopped' then
        local location = proxy:query('get-current-frame-location')
        log.debug({"current frame location", location})
        if #location == 2 then
          local fname = location[1]
          local line = location[2]
          if (fname ~= self.prev_fname or line ~= self.prev_line) then
            self.prev_line = line
            self.prev_fname = fname
            self.actions:jump_to_source(fname, line)
          end
        end
      end
      self.actions:query_breakpoints()
      self.state = process_state == 'running' and self.running or self.paused
    end))
    -- Don't change the state yet
    return self.state
  end

  local re_prompt = '$'
  self.add_trans(self.paused, '[\r\n]Continuing%.', self._paused_continue)
  self.add_trans(self.paused, '[\r\n]Starting program:', self._paused_continue)
  self.add_trans(self.paused, re_prompt, self.query_paused)
  self.add_trans(self.running, re_prompt, self.query_paused)

  self.state = self.running

  return self
end

---@async
---@param fname string full path to the source
---@param proxy Proxy connection to the side channel
---@return FileBreakpoints collection of actual breakpoints
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

---@type CommandMap
C.command_map = {
  delete_breakpoints = 'delete',
  breakpoint = 'break',
  ['info breakpoints'] = 'info breakpoints',
}

---@return string[]
function C.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  return {[[%m\ at\ %f:%l]], [[%m\ %f:%l]]}
end

---@param client_cmd string[] original debugger command
---@param tmp_dir string path to the session state directory
---@param proxy_addr string full path to the file with the udp port in the session state directory
---@return string[] command to launch the debugger with termopen()
function C.get_launch_cmd(client_cmd, tmp_dir, proxy_addr)

  -- Assuming the first argument is path to gdb, the rest are arguments.
  -- We'd like to ensure gdb is launched with our custom initialization
  -- injected.

  local cmd_arg = "-ix"
  local rest_arg_idx = 2
  local cmd = {client_cmd[1]}
  if cmd[1] == "rr-replay.py" then
    -- Check for rr-replay.py
    cmd = {utils.get_plugin_file_path("lib", "rr-replay.py")}
  elseif cmd[1] == "cargo-debug" then
    -- Check for cargo
    cmd_arg = "--command-file"
  elseif cmd[1] == "cargo" then
    -- the 2nd arg is the cargo's subcommand, should be 'debug' here
    cmd = {'cargo', client_cmd[2]}
    cmd_arg = "--command-file"
    rest_arg_idx = 3
  end

  local gdb_init = utils.path_join(tmp_dir, "gdb_init")
  local file = io.open(gdb_init, "w")
  assert(file, "Failed to open gdb_init for writing")
  if file then
    file:write([[
set confirm off
set pagination off
]])
    file:write("source " .. utils.get_plugin_file_path("lib", "gdb_commands.py") .. "\n")
    file:write("nvim-gdb-init " .. proxy_addr .. "\n")
    if utils.is_windows then
      -- Change code page to UTF-8 in Windows, required to avoid distortion of characters like \x1a (^Z)
      file:write("!chcp 65001\n")
    end
    file:close()
  end

  table.insert(cmd, cmd_arg)
  table.insert(cmd, gdb_init)
  -- Append the rest of arguments
  for i = rest_arg_idx, #client_cmd do
    cmd[#cmd + 1] = client_cmd[i]
  end
  return cmd
end

return C
