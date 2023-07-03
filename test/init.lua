vim.cmd("language C")
vim.o.rtp = vim.env.VIMRUNTIME .. ',' .. vim.loop.fs_realpath('..')
vim.g.mapleader = ' '
vim.g.loaded_matchparen = 1   -- Don't load stock plugins to simplify debugging
vim.g.loaded_netrwPlugin = 1
vim.o.shortmess = 'a'
vim.o.cmdheight = 5
vim.o.hidden = true
vim.o.ruler = false
vim.o.showcmd = false

vim.cmd("runtime! plugin/*.vim")
