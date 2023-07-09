-- custom_output.lua

local hook = require'output_hook'
hook.init()

local old_io_write = io.write
io.write = hook.write
local old_io_flush = io.flush
io.flush = hook.flush

local ret = require'busted.outputHandlers.gtest'

io.write = old_io_write
io.flush = old_io_flush

return ret
