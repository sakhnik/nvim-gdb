
" pdb specifics
function! nvimgdb#backend#pdb#create()
  let backend = {
    \ 'init_state': 'paused',
    \ 'init': [],
    \ 'paused': [
    \     ['\v-@<!\> ([^(]+)\((\d+)\)[^(]+\(\)', 'jump'],
    \     ['^(Pdb) ', 'info_breakpoints'],
    \ ],
    \ 'running': [
    \ ],
    \ 'delete_breakpoints': 'clear',
    \ 'breakpoint': 'break',
    \ 'finish': 'return',
    \ 'until' : 'until',
    \ }
  return backend
endfunction
