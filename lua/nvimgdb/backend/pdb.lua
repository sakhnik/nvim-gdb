-- PDB specifics
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local Common = require'nvimgdb.backend.common'
local ParserImpl = require'nvimgdb.parser_impl'

-- @class BackendPdb:Backend @specifics of PDB
local C = {}
C.__index = C
setmetatable(C, {__index = Common})

-- @return BackendPdb @new instance
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

  local re_jump = '[\r\n ]> ([^(]+)%((%d+)%)[^(]+%(%)'
  if vim.loop.os_uname().sysname:find('Windows') ~= nil then
    re_jump = '> ([^(]+)%((%d+)%)[^(]+%(%)'
  end
  local re_prompt = '[\r\n]%(Pdb%+?%+?%) *$'
  self.add_trans(self.paused, re_jump, self._paused_jump)
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

-- @param fname string @full path to the source
-- @param proxy Proxy @connection to the side channel
-- @return FileBreakpoints @collection of actual breakpoints
function C.query_breakpoints(fname, proxy)
  -- Query actual breakpoints for the given file.
  log.info("Query breakpoints for " .. fname)

  local response = proxy:query('handle-command break')

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
      local jump_regex = "^([^:]+):([0-9]+)$"
      if vim.loop.os_uname().sysname:find('Windows') ~= nil then
        -- c:\full\path\test.py
        jump_regex = "^([^:]+:[^:]+):([0-9]+)$"
      end
      local bpfname, lnum = tokens[#tokens]:match(jump_regex)
      if fname == bpfname then
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

-- @type CommandMap
C.command_map = {
  delete_breakpoints = 'clear',
  breakpoint = 'break',
  finish = 'return',
  ['print %s'] = 'print(%s)',
  ['info breakpoints'] = 'break',
}

-- @return string[]
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

return C
