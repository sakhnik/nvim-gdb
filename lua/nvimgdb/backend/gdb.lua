-- GDB specifics
-- vim: set et ts=2 sw=2:

c = {}

function c.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  return {[[%m\ at\ %f:%l]], [[%m\ %f:%l]]}
end

return c
