-- custom_output.lua

local hook = require'output_hook'
hook.init()

local old_io_write = io.write
io.write = hook.write
local old_io_flush = io.flush
io.flush = hook.flush

local outputHandler = require'busted.outputHandlers.gtest'

local ret = function(options)
  local handler = outputHandler(options)
  -- Update the failure count at the suite end
  require'busted'.subscribe({ 'suite', 'end' }, function()
    require'result'.failures = #handler.failures + #handler.errors
  end)
  return handler
end

io.write = old_io_write
io.flush = old_io_flush

return ret
