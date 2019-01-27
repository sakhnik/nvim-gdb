" Define the sign for current line the debugged program is executing.
sign define GdbCurrentLine text=▶

" Define signs for the breakpoints.
let s:breakpoint_signs = ['●', '●²', '●³', '●⁴', '●⁵', '●⁶', '●⁷', '●⁸', '●⁹', '●ⁿ']
for i in range(len(s:breakpoint_signs))
  exe 'sign define GdbBreakpoint' . (i+1) . ' text=' . s:breakpoint_signs[i]
endfor

lua gdb = require("gdb.app")


function! s:GdbKill()
  " Prevent "ghost" [noname] buffers when leaving debug when 'hidden' is on
  if &hidden
    set nohidden
    let l:hidden = 1
  else
    let l:hidden = 0
  endif

  " Cleanup commands, autocommands etc
  call nvimgdb#ui#Leave()

  lua gdb.cleanup()

  " TabEnter isn't fired automatically when a tab is closed
  lua gdb.tabEnter()

  " sets hidden back to user default
  if l:hidden
    set hidden
  endif
endfunction


" The checks to be executed when navigating the windows
function! nvimgdb#CheckWindowClosed(...)
  " If this isn't a debugging session, nothing to do
  if !luaeval("gdb.checkTab()") | return | endif

  " The tabpage should contain at least two windows, finish debugging
  " otherwise.
  if tabpagewinnr(tabpagenr(), '$') == 1
    call s:GdbKill()
  endif
endfunction


function! nvimgdb#Spawn(backend, proxy_cmd, client_cmd)
  call luaeval("gdb.init(_A[1], _A[2], _A[3])", [a:backend, a:proxy_cmd, a:client_cmd])

  " Initialize the UI commands, autocommands etc
  call nvimgdb#ui#Enter()
endfunction


function! nvimgdb#Kill()
  if !luaeval("gdb.checkTab()") | return | endif
  call s:GdbKill()
endfunction

let s:plugin_dir = expand('<sfile>:p:h:h')

function! nvimgdb#GetPluginDir()
  return s:plugin_dir
endfunction

function! nvimgdb#TermOpen(command, tab)
  return termopen(a:command,
    \ {'on_stdout': {j,d,e -> luaeval("gdb.onStdout(_A[1], _A[2], _A[3], _A[4])", [a:tab,j,d,e])}
    \ })
endfunction
