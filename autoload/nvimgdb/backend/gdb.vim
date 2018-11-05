
" gdb specifics
function! nvimgdb#backend#gdb#Get()
  let backend = {
    \ 'init_state': 'running',
    \ 'paused': [
    \     ['Continuing.', 'continue'],
    \     ['\v[\o32]{2}([^:]+):(\d+):\d+', 'jump'],
    \     ['^(gdb) ', 'info_breakpoints'],
    \ ],
    \ 'running': [
    \     ['\v^Breakpoint \d+', 'pause'],
    \     ['\v hit Breakpoint \d+', 'pause'],
    \     ['^(gdb) ', 'pause'],
    \ ],
    \ 'delete_breakpoints': 'delete',
    \ 'breakpoint': 'break',
    \ 'until' : 'until',
    \ }
  return backend
endfunction
