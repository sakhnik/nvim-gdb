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
  lua gdb.keymaps:setT()
  tnoremap <buffer> <silent> ~tkm <c-\><c-n>:let g:test_tkeymap = 1<cr>i
endfunction

function! MySetKeymaps()
  lua gdb.keymaps:set()
  " One custom programmable keymap needed in some tests
  nnoremap <buffer> <silent> ~tn :let g:test_keymap = 1<cr>
endfunction

function! MyUnsetKeymaps()
  lua gdb.keymaps:unset()
  " Unset the custom programmable keymap
  nunmap <buffer> ~tn
endfunction

let g:nvimgdb_config_override = {
  \ 'set_tkeymaps': 'MySetTKeymaps',
  \ 'set_keymaps': 'MySetKeymaps',
  \ 'unset_keymaps': 'MyUnsetKeymaps',
  \ }
