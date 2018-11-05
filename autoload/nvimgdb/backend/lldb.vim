
" lldb specifics
function! nvimgdb#backend#lldb#Get()
  let backend = {
    \ 'init_state': 'running',
    \ 'paused': [
    \     ['\v^Process \d+ resuming', 'continue'],
    \     ['\v at [\o32]{2}([^:]+):(\d+)', 'jump'],
    \     ['(lldb)', 'info_breakpoints'],
    \ ],
    \ 'running': [
    \     ['\v^Breakpoint \d+:', 'pause'],
    \     ['\v^Process \d+ stopped', 'pause'],
    \     ['(lldb)', 'pause'],
    \ ],
    \ 'delete_breakpoints': 'breakpoint delete',
    \ 'breakpoint': 'b',
    \ 'until' : 'thread until',
    \ }
  return backend
endfunction
