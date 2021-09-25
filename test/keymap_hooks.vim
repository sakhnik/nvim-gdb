" This file can be used as an example of how to add custom keymaps

" Flags for test keymaps
let g:test_tkeymap = 0
let g:test_keymap = 0

" A hook function to set keymaps in the terminal window
function! MySetTKeymaps()
  lua NvimGdb.i().keymaps:set_t()
  tnoremap <buffer> <silent> ~tkm <c-\><c-n>:let g:test_tkeymap = 1<cr>i
endfunction

" A hook function to key keymaps in the code window.
" Will be called every time the code window is entered
function! MySetKeymaps()
  " First set up the stock keymaps
  lua NvimGdb.i().keymaps:set()

  " Then there can follow any additional custom keymaps. For example,

  " One custom programmable keymap needed in some tests
  nnoremap <buffer> <silent> ~tn :let g:test_keymap = 1<cr>
endfunction

" A hook function to unset keymaps in the code window
" Will be called every time the code window is left
function! MyUnsetKeymaps()
  " Unset the custom programmable keymap created in MySetKeymap
  nunmap <buffer> ~tn

  " Then unset the stock keymaps
  lua NvimGdb.i().keymaps:unset()
endfunction

" Declare in the configuration that there are custom keymap handlers
let g:nvimgdb_config_override = {
  \ 'set_tkeymaps': 'MySetTKeymaps',
  \ 'set_keymaps': 'MySetKeymaps',
  \ 'unset_keymaps': 'MyUnsetKeymaps',
  \ }
