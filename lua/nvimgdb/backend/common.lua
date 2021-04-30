-- vim: set et ts=2 sw=2:

-- @class Backend
local C = {}
C.__index = C

-- Create a parser to recognize state changes and code jumps
-- @param actions ParserActions @callbacks for the parser
-- @return ParserImpl @new parser instance
function C.create_parser(actions)
  local _ = actions
  return assert(nil, "Not implemented")
end

-- @alias FileBreakpoints table<string, string[]> @{line = {break_id}}
-- @alias QueryBreakpoints fun(fname:string, proxy:Proxy):FileBreakpoints

-- @param fname string @full path to the source
-- @param proxy Proxy @connection to the side channel
-- @return FileBreakpoints @collection of actual breakpoints
function C.query_breakpoints(fname, proxy)
  local _ = fname
  local _ = proxy
  return assert(nil, "Not implemented")
end

-- @alias CommandMap table<string, string>
-- @type CommandMap @map from generic commands to specific commands
C.command_map = {}

-- Adapt command if necessary.
-- @param command string @generic debugger command
-- @return string @translated command for a specific backend
function C:translate_command(command)
  local cmd = self.command_map[command]
  if cmd ~= nil then
    return cmd
  end
  return command
end

-- @return string[] @errorformats to setup for this backend
function C.get_error_formats()
  return assert(nil, "Not implemented")
end

return C
