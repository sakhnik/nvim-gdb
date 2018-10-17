language C
exe 'set rtp+='.expand('<sfile>:h:h')
let mapleader=' '


" Test custom configuration
let g:test_tkeymap = 0
let g:test_keymap = 0

function! MySetTKeymaps()
  call nvimgdb#SetTKeymaps()
  tnoremap <buffer> <silent> <leader>tkm <c-\><c-n>:let g:test_tkeymap = 1<cr>i
endfunction

function! MySetKeymaps()
  call nvimgdb#SetKeymaps()
  " One custom programmable keymap needed in some tests
  nnoremap <buffer> <silent> <leader>tn :let g:test_keymap = 1<cr>
endfunction

function! MyUnsetKeymaps()
  call nvimgdb#UnsetKeymaps()
  " Unset the custom programmable keymap
  nunmap <buffer> <leader>tn
endfunction

let g:nvimgdb_config_overload = {
  \ 'set_tkeymaps': funcref('MySetTKeymaps'),
  \ 'set_keymaps': funcref('MySetKeymaps'),
  \ 'unset_keymaps': funcref('MyUnsetKeymaps'),
  \ }
