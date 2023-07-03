language C
set rtp=$VIMRUNTIME
exe 'set rtp+='.expand('<sfile>:h:h')
let mapleader=' '
let g:loaded_matchparen = 1   " Don't load stock plugins to simplify debugging
let g:loaded_netrwPlugin = 1
set shortmess=a
set cmdheight=5
set hidden
set noruler noshowcmd
runtime! plugin/*.vim
