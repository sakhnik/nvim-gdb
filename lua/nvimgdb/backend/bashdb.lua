-- BashDB specifics
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local Backend = require'nvimgdb.backend'
local ParserImpl = require'nvimgdb.parser_impl'
local utils = require'nvimgdb.utils'

---@class BackendBashdb: Backend specifics of BashDB
local C = {}
C.__index = C
setmetatable(C, {__index = Backend})

---@return BackendBashdb new instance
function C.new()
  local self = setmetatable({}, C)
  return self
end

---Create a parser to recognize state changes and code jumps
---@param actions ParserActions callbacks for the parser
---@param proxy Proxy side channel connection to the debugger
---@return ParserImpl new parser instance
function C.create_parser(actions, proxy)
  local _ = proxy
  local P = {}
  P.__index = P
  setmetatable(P, {__index = ParserImpl})

  local self = setmetatable({}, P)
  self:_init(actions)

  local re_jump = '[\r\n]%(([^:]+):(%d+)%):[\r\n]'
  local re_prompt = '[\r\n]bashdb<%(?%d+%)?> $'
  local re_term = '[\r\n]Debugged program terminated '
  self.add_trans(self.paused, re_jump, self._paused_jump)

  function P:_handle_terminated(_)
    self.actions:continue_program()
    return self.paused
  end

  self.add_trans(self.paused, re_term, self._handle_terminated)
  -- Make sure the prompt is matched in the last turn to exhaust
  -- every other possibility while parsing delayed.
  self.add_trans(self.paused, re_prompt, self._query_b)

  -- Let's start the backend in the running state for the tests
  -- to be able to determine when the launch finished.
  -- It'll transition to the paused state once and will remain there.

  function P:_running_jump(fname, line)
    log.info("_running_jump " .. fname .. ":" .. line)
    self.actions:jump_to_source(fname, tonumber(line))
    return self.running
  end

  self.add_trans(self.running, re_jump, self._running_jump)
  self.add_trans(self.running, re_prompt, self._query_b)
  self.state = self.running

  return self
end

---@param fname string full path to the source
---@param proxy Proxy connection to the side channel
---@return FileBreakpoints collection of actual breakpoints
function C.query_breakpoints(fname, proxy)
  log.info("Query breakpoints for " .. fname)
  local response = proxy:query('handle-command info breakpoints')
  if response == nil or type(response) ~= 'string' or response == "" then
    return {}
  end

  -- Select lines in the current file with enabled breakpoints.
  local breaks = {}
  for line in response:gmatch("[^\r\n]+") do
    local fields = {}
    for field in line:gmatch("[^%s]+") do
      fields[#fields + 1] = field
    end
    if fields[4] == 'y' then    -- Is enabled?
      local bpfname, lnum = fields[#fields]:match("^([^:]+):(%d+)$")  -- file.cpp:line
      if bpfname ~= nil then
        if bpfname == fname or vim.loop.fs_realpath(fname) == vim.loop.fs_realpath(bpfname) then
          local br_id = fields[1]
          local list = breaks[lnum]
          if list == nil then
            breaks[lnum] = {br_id}
          else
            list[#list + 1] = br_id
          end
        end
      end
    end
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
  return {[[%m\ in\ file\ `%f'\ at\ line\ %l]],
          [[%m\ called\ from\ file\ `%f'\ at\ line\ %l]],
          [[%m\ %f:%l]]}

  -- bashdb<18> bt
  -- ->0 in file `main.sh' at line 8
  -- ##1 Foo("1") called from file `main.sh' at line 18
  -- ##2 Main() called from file `main.sh' at line 22
  -- ##3 source("main.sh") called from file `/sbin/bashdb' at line 107
  -- ##4 main("main.sh") called from file `/sbin/bashdb' at line 0
  -- bashdb<22> info breakpoints
  -- Num Type       Disp Enb What
  -- 1   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:16
  --         breakpoint already hit 1 time
  -- 2   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:7
  --         breakpoint already hit 1 time
  -- 3   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:3
  -- 4   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:8
end

---@param client_cmd string[] original debugger command
---@param tmp_dir string path to the session state directory
---@param proxy_addr string full path to the file with the udp port in the session state directory
---@return string[] command to launch the debugger with termopen()
function C.get_launch_cmd(client_cmd, tmp_dir, proxy_addr)
  local _ = tmp_dir
  local cmd = {"python", utils.get_plugin_file_path('lib', 'proxy', 'bashdb.py'), '-a', proxy_addr}
  -- Append the rest of arguments
  for i = 1, #client_cmd do
    cmd[#cmd + 1] = client_cmd[i]
  end
  return cmd
end

return C
