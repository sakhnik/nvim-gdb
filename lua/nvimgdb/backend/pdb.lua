-- PDB specifics
-- vim: set et ts=2 sw=2:

local C = {}
local log = require'nvimgdb.log'

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
      local bpfname, line = tokens[#tokens]:match("^([^:]+):(.+)$")
      if fname == bpfname then
        local list = breaks[line]
        if list == nil then
          breaks[line] = {bid}
        else
          list[#list + 1] = bid
        end
      end
    end
  end
  return breaks
end

function C.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  return {[[%m\ at\ %f:%l]], [[%[>\ ]%#%f(%l)%m]]}

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
end

return C
