language C
exe 'set rtp+='.expand('<sfile>:h:h')
let mapleader=' '
let g:loaded_matchparen = 1   " Don't load stock plugins to simplify debugging
let g:loaded_netrwPlugin = 1
set shortmess=a
set cmdheight=5


" Test custom configuration
let g:test_tkeymap = 0
let g:test_keymap = 0

function! MySetTKeymaps()
  call nvimgdb#keymaps#SetT()
  tnoremap <buffer> <silent> ~tkm <c-\><c-n>:let g:test_tkeymap = 1<cr>i
endfunction

function! MySetKeymaps()
  call nvimgdb#keymaps#Set()
  " One custom programmable keymap needed in some tests
  nnoremap <buffer> <silent> ~tn :let g:test_keymap = 1<cr>
endfunction

function! MyUnsetKeymaps()
  call nvimgdb#keymaps#Unset()
  " Unset the custom programmable keymap
  nunmap <buffer> ~tn
endfunction

let g:nvimgdb_config_override = {
  \ 'set_tkeymaps': funcref('MySetTKeymaps'),
  \ 'set_keymaps': funcref('MySetKeymaps'),
  \ 'unset_keymaps': funcref('MyUnsetKeymaps'),
  \ }
