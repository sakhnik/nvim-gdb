sign define GdbCurrentLine text=⇒
sign define GdbBreakpoint text=●

lua V = require("gdb.v")
lua gdb = require("gdb.app")


function! s:GdbKill()
  " Cleanup commands, autocommands etc
  call nvimgdb#ui#Leave()

  lua gdb.cleanup()

  " TabEnter isn't fired automatically when a tab is closed
  lua gdb.tabEnter()
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

  " Set initial keymaps in the terminal window.
  " This should be done after the app have been initialized,
  " because the user callbacks may dispatch through there.
  lua gdb.keymaps:dispatchSetT()
  lua gdb.keymaps:dispatchSet()

  " Initialize the UI commands, autocommands etc
  call nvimgdb#ui#Enter()

  " Start insert mode in the GDB window
  normal i
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
