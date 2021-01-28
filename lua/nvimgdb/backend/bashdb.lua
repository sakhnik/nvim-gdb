-- BashDB specifics
-- vim: set et ts=2 sw=2:

local C = {}
local log = require'nvimgdb.log'

function C.query_breakpoints(fname, proxy)
  log.info("Query breakpoints for " .. fname)
  local response = proxy:query('handle-command info breakpoints')
  if response == nil or response == "" then
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
      local bpfname, line = fields[#fields]:match("^([^:]+):(%d+)$")  -- file.cpp:line
      if bpfname ~= nil then
        if bpfname == fname or vim.loop.fs_realpath(fname) == vim.loop.fs_realpath(bpfname) then
          local br_id = fields[1]
          local list = breaks[line]
          if list == nil then
            breaks[line] = {br_id}
          else
            list[#list + 1] = br_id
          end
        end
      end
    end
  end
  return breaks
end

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

return C
