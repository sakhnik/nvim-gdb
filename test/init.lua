if vim.loop.os_uname().sysname:find('Darwin') == nil then
  -- Command not available in nvim-macos
  vim.cmd("language C")
end
local plugin_dir = vim.loop.fs_realpath('..')
vim.o.rtp = vim.env.VIMRUNTIME .. ',' .. plugin_dir
vim.g.mapleader = ' '
vim.g.loaded_matchparen = 1   -- Don't load stock plugins to simplify debugging
vim.g.loaded_netrwPlugin = 1
vim.o.shortmess = 'a'
vim.o.cmdheight = 5
vim.o.hidden = true
vim.o.ruler = false
vim.o.showcmd = false

-- Avoid messages being echoed to minimize the risk of hit-enter
vim.notify = function() end

vim.cmd("runtime! plugin/*.vim")

local rocks_dir = plugin_dir .. '/lua_modules/share/lua/5.1'
package.path = rocks_dir .. '/?.lua;' .. rocks_dir .. '/?/init.lua;' .. package.path

local utils = require'nvimgdb.utils'
local so = utils.is_windows and '.dll' or '.so'
package.cpath = plugin_dir .. '/lua_modules/lib/lua/5.1/?' .. so .. ';' .. package.cpath
