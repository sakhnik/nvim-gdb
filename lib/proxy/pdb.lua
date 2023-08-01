local uv = vim.loop

local dir = uv.fs_realpath(arg[0]:match('^(.*)[/\\]'))
package.path = dir .. '/?.lua;' .. package.path

local Proxy = require'base'

local proxy = Proxy.new('[\n\r]%(Pdb%+*%) *')
proxy:start()
vim.wait(10^9, function() return false end)
