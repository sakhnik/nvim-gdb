-- GDB specifics
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local C = {}

function C.query_breakpoints(fname, proxy)
  log.info("Query breakpoints for " .. fname)
  response = proxy:query('handle-command info breakpoints')
  if response == nil or response == '' then
    return {}
  end

  -- Select lines in the current file with enabled breakpoints.
  breaks = {}
  for line in response:gmatch("[^\n\r]+") do
    if line:find("%sy%s+0x") ~= nil then    -- Is enabled?
      fields = {}
      for field in line:gmatch("[^s]+") do
        fields[#fields+1] = field
      end
      -- file.cpp:line
      bpfname, line = fields[#fields]:match("^([^:]+):(%d+)$")
      if bpfname ~= nil then
        is_end_match = fname:sub(-#bpfname) == bpfname  -- ends with
        -- Try with the real path too
        bpfname = vim.loop.fs_realpath(bpfname)
        is_end_match_full_path = bpfname ~= nil and fname:sub(-#bpfname) == bpfname

        if is_end_match or is_end_match_full_path then
          -- If a breakpoint has multiple locations, GDB only
          -- allows to disable by the breakpoint number, not
          -- location number.  For instance, 1.4 -> 1
          bid = fields[1]:gmatch("[^.]+")()
          list = breaks[line]
          if list == nil then
            breaks[line] = {bid}
          else
            list[#list + 1] = bid
          end
        end
      end
    end
  end

  return breaks
end

function C.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  return {[[%m\ at\ %f:%l]], [[%m\ %f:%l]]}
end

return C
