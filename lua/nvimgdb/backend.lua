-- vim: set et ts=2 sw=2:

---@class Backend
local C = {}
C.__index = C

---Create a parser to recognize state changes and code jumps
---@param actions ParserActions callbacks for the parser
---@param proxy Proxy side channel connection to the debugger
---@return ParserImpl new parser instance
function C.create_parser(actions, proxy)
  local _ = actions
  local _ = proxy
  return assert(nil, "Not implemented")
end

---@param fname string full path to the source
---@param proxy Proxy connection to the side channel
---@return FileBreakpoints collection of actual breakpoints
function C.query_breakpoints(fname, proxy)
  local _ = fname
  local _ = proxy
  return assert(nil, "Not implemented")
end

---@alias CommandMap table<string, string>
---@type CommandMap map from generic commands to specific commands
C.command_map = {}

---Adapt command if necessary.
---@param command string generic debugger command
---@return string translated command for a specific backend
function C:translate_command(command)
  local cmd = self.command_map[command]
  if cmd ~= nil then
    return cmd
  end
  return command
end

---@return string[] errorformats to setup for this backend
function C.get_error_formats()
  return {}
end

-- @param client_cmd string[] @original debugger command
-- @param tmp_dir string @path to the session state directory
-- @param proxy_addr string @full path to the file with the udp port in the session state directory
-- @return string[] @command to launch the debugger with termopen()
function C.get_launch_cmd(client_cmd, tmp_dir, proxy_addr)
  local _ = client_cmd
  local _ = tmp_dir
  local _ = proxy_addr
end

return C
