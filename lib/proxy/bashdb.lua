local uv = vim.loop

local dir = uv.fs_realpath(arg[0]:match('^(.*)[/\\]'))
package.path = dir .. '/?.lua;' .. dir .. '/../../lua/?.lua;' .. package.path

local log = require'nvimgdb.log'
log.set_filename('bashdb.log')
local Proxy = require'impl'

local proxy = Proxy.new('[\r\n]bashdb<%(?%d+%)?> ')
proxy:start()
vim.wait(10^9, function() return false end)
