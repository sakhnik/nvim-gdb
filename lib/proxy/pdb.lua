local uv = vim.loop

local dir = uv.fs_realpath(arg[0]:match('^(.*)[/\\]'))
package.path = dir .. '/?.lua;' .. dir .. '/../../lua/?.lua;' .. package.path

local log = require'nvimgdb.log'
log.set_filename('pdb.log')
local ProxyImpl = require'impl'

local proxy = ProxyImpl.new('[\n\r]%(Pdb%+*%) *')
proxy:start()
vim.wait(10^9, function() return false end)
