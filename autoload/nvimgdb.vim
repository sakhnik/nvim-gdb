sign define GdbCurrentLine text=⇒
sign define GdbBreakpoint text=●

lua V = require("gdb.v")
lua gdb = require("gdb")


function! s:GdbKill()
  " Cleanup commands, autocommands etc
  call nvimgdb#ui#Leave()

  lua gdb.app.cleanup()

  " TabEnter isn't fired automatically when a tab is closed
  lua gdb.app.dispatch("tabEnter")
endfunction


" The checks to be executed when navigating the windows
function! nvimgdb#CheckWindowClosed(...)
  " If this isn't a debugging session, nothing to do
  if !luaeval("gdb.app.checkTab()") | return | endif

  " The tabpage should contain at least two windows, finish debugging
  " otherwise.
  if tabpagewinnr(tabpagenr(), '$') == 1
    call s:GdbKill()
  endif
endfunction

function! nvimgdb#OnBufEnter()
  if !luaeval("gdb.app.checkTab()") | return | endif
  if &buftype ==# 'terminal' | return | endif

  " Make sure the cursor stays visible at all times
  if !&scrolloff | setlocal scrolloff=5 | endif

  call nvimgdb#keymaps#DispatchSet()
  " Ensure breakpoints are shown if are queried dynamically
  lua gdb.win.queryBreakpoints()
endfunction

function! nvimgdb#OnBufLeave()
  if !luaeval("gdb.app.checkTab()") | return | endif
  if &buftype ==# 'terminal' | return | endif
  call nvimgdb#keymaps#DispatchUnset()
endfunction


function! nvimgdb#Spawn(backend, proxy_cmd, client_cmd)
  call luaeval("gdb.app.init(_A[1], _A[2], _A[3])", [a:backend, a:proxy_cmd, a:client_cmd])

  " Prepare configuration specific to this debugging session
  call nvimgdb#keymaps#Init()

  " Initialize the UI commands, autocommands etc
  call nvimgdb#ui#Enter()

  " Set terminal window keymaps
  call nvimgdb#keymaps#DispatchSetT()

  " Set normal mode keymaps too
  call nvimgdb#keymaps#DispatchSet()

  " Start inset mode in the GDB window
  normal i
endfunction


function! nvimgdb#Send(data)
  if !luaeval("gdb.app.checkTab()") | return | endif
  call luaeval("gdb.client.sendLine(gdb.app.dispatch('getCommand', _A))", a:data)
endfunction


function! nvimgdb#Eval(expr)
  call nvimgdb#Send(printf('print %s', a:expr))
endfunction


function! nvimgdb#Interrupt()
  if !luaeval("gdb.app.checkTab()") | return | endif
  lua gdb.client.interrupt()
endfunction


function! nvimgdb#Kill()
  if !luaeval("gdb.app.checkTab()") | return | endif
  call s:GdbKill()
endfunction

let s:plugin_dir = expand('<sfile>:p:h:h')

function! nvimgdb#GetPluginDir()
  return s:plugin_dir
endfunction

function! nvimgdb#TermOpen(command, tab)
  enew
  " TODO: Fix dispatching to the specified tab, not the current one
  return termopen(a:command,
    \ {'tab': a:tab,
    \  'on_stdout': {j,d,e -> luaeval("gdb.app.dispatch('onStdout', _A[1], _A[2], _A[3])", [j,d,e])}
    \ })
endfunction
