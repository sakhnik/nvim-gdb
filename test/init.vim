language C
exe 'set rtp+='.expand('<sfile>:h:h')
let mapleader=' '

" Test custom configuration
function! MySetKeymaps()
  call nvimgdb#SetKeymaps()
  " One custom programmable keymap needed in some tests
  nnoremap <buffer> <silent> <leader>dn :GdbNext<cr>
endfunction

function! MyUnsetKeymaps()
  call nvimgdb#UnsetKeymaps()
  " Unset the custom programmable keymap
  nunmap <buffer> <leader>dn
endfunction

let g:nvimgdb_config_overload = {
  \ 'set_keymaps': funcref('MySetKeymaps'),
  \ 'unset_keymaps': funcref('MyUnsetKeymaps'),
  \ }
