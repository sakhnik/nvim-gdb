-- LLDB specifics
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local C = {}

function C.query_breakpoints(fname, proxy) 
  log.info("Query breakpoints for " .. fname)
  resp = proxy:query('info-breakpoints ' .. fname)
  if resp == nil or resp == '' then
    return {}
  end
  -- We expect the proxies to send breakpoints for a given file
  -- as a map of lines to array of breakpoint ids set in those lines.
  breaks = vim.fn.json_decode(resp)
  err = breaks._error
  if err ~= nil then
    log.error("Can't get breakpoints: " .. err)
    return {}
  end
  return breaks
end

function C.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  -- Breakpoint list is queried specifically with a custom command
  -- nvim-gdb-info-breakpoints, which is only implemented in the proxy.
  return {[[%m\ at\ %f:%l]], [[%f:%l\ %m]]}
end

return C
