-- PDB specifics
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local Backend = require'nvimgdb.backend'
local ParserImpl = require'nvimgdb.parser_impl'
local utils = require'nvimgdb.utils'

---@class BackendPdb: Backend specifics of PDB
local C = {}
C.__index = C
setmetatable(C, {__index = Backend})

---@return BackendPdb new instance
function C.new()
  local self = setmetatable({}, C)
  return self
end

local for_win32 = function(win32, other)
  if utils.is_windows then
    return win32
  end
  return other
end

local U = {
  re_jump = for_win32('> ([^(]+)%((%d+)%)[^(]+%(%)', '[\r\n ]> ([^(]+)%((%d+)%)[^(]+%(%)'),
  -- c:\full\path\test.py
  jump_regex = for_win32('^([^:]+:[^:]+):([0-9]+)$', '^([^:]+):([0-9]+)$'),
  strieq = for_win32(function(a, b) return a:lower() == b:lower() end,
                      function(a, b) return a == b end)
}

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

  local re_prompt = '[\r\n]%(Pdb%+?%+?%)[\r ]*$'
  self.add_trans(self.paused, U.re_jump, self._paused_jump)
  self.add_trans(self.paused, re_prompt, self._query_b)

  -- Let's start the backend in the running state for the tests
  -- to be able to determine when the launch finished.
  -- It'll transition to the paused state once and will remain there.
  function P:_running_jump(fname, line)
    log.info("_running_jump " .. fname .. ":" .. line)
    self.actions:jump_to_source(fname, tonumber(line))
    return self.running
  end

  self.add_trans(self.running, U.re_jump, self._running_jump)
  self.add_trans(self.running, re_prompt, self._query_b)
  self.state = self.running
  return self
end

---@async
---@param fname string full path to the source
---@param proxy Proxy connection to the side channel
---@return FileBreakpoints collection of actual breakpoints
function C.query_breakpoints(fname, proxy)
  -- Query actual breakpoints for the given file.
  log.info("Query breakpoints for " .. fname)

  local response = proxy:query('handle-command break')
  if response == nil or type(response) ~= 'string' or response == '' then
    return {}
  end

  -- Num Type         Disp Enb   Where
  -- 1   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:8

  local breaks = {}
  for line in response:gmatch('[^\r\n]+') do
    local tokens = {}
    for token in line:gmatch('[^%s]+') do
      tokens[#tokens+1] = token
    end
    local bid = tokens[1]
    if tokens[2] == 'breakpoint' and tokens[4] == 'yes' then
      local bpfname, lnum = tokens[#tokens]:match(U.jump_regex)
      if bpfname ~= nil and U.strieq(fname, bpfname) then
        local list = breaks[lnum]
        if list == nil then
          breaks[lnum] = {bid}
        else
          list[#list + 1] = bid
        end
      end
    end
  end
  return breaks
end

---@type CommandMap
C.command_map = {
  delete_breakpoints = 'clear',
  breakpoint = 'break',
  finish = 'return',
  ['print %s'] = 'print(%s)',
  ['info breakpoints'] = 'break',
}

---@return string[]
function C.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  return {[[%m\ at\ %f:%l]], [[[%[0-9]%#]%[>\ ]%#%f(%l)%m]], [[%[>\ ]%#%f(%l)%m]]}

  -- (Pdb) break
  -- Num Type         Disp Enb   Where
  -- 1   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:14
  -- 2   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:4
  -- (Pdb) bt
  --   /usr/lib/python3.9/bdb.py(580)run()
  -- -> exec(cmd, globals, locals)
  --   <string>(1)<module>()
  --   /tmp/nvim-gdb/test/main.py(22)<module>()
  -- -> _main()
  --   /tmp/nvim-gdb/test/main.py(16)_main()
  -- -> _foo(i)
  --   /tmp/nvim-gdb/test/main.py(11)_foo()
  -- -> return num + _bar(num - 1)
  -- > /tmp/nvim-gdb/test/main.py(5)_bar()

  -- Pdb++ may produce a different backtrace:
  -- (Pdb++) bt
  -- [0]   /usr/lib/python3.9/bdb.py(580)run()
  -- -> exec(cmd, globals, locals)
  -- [1]   <string>(1)<module>()
  -- [2]   /tmp/nvim-gdb/test/main.py(22)<module>()
  -- -> _main()
  -- [3]   /tmp/nvim-gdb/test/main.py(16)_main()
  -- -> _foo(i)
  -- [4]   /tmp/nvim-gdb/test/main.py(11)_foo()
  -- -> return num + _bar(num - 1)
  -- [5] > /tmp/nvim-gdb/test/main.py(5)_bar()
  -- -> return i * 2
end

---@param client_cmd string[] original debugger command
---@param tmp_dir string path to the session state directory
---@param proxy_addr string full path to the file with the udp port in the session state directory
---@return string[] command to launch the debugger with termopen()
function C.get_launch_cmd(client_cmd, tmp_dir, proxy_addr)
  local _ = tmp_dir
  local cmd = {'nvim', '--clean', '-u', 'NONE', '-l', utils.get_plugin_file_path('lib', 'proxy', 'base.lua'), '-a', proxy_addr}
  -- Append the rest of arguments
  for i = 1, #client_cmd do
    cmd[#cmd + 1] = client_cmd[i]
  end
  return cmd
end

return C
