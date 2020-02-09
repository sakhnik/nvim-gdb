
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

  call GdbCleanup()

  " TabEnter isn't fired automatically when a tab is closed
  call GdbHandleEvent("on_tab_enter")

  " sets hidden back to user default
  if l:hidden
    set hidden
  endif
endfunction


" The checks to be executed when navigating the windows
function! nvimgdb#CheckWindowClosed(...)
  " If this isn't a debugging session, nothing to do
  if !GdbCheckTab() | return | endif

  " The tabpage should contain at least two windows, finish debugging
  " otherwise.
  if tabpagewinnr(tabpagenr(), '$') == 1
    call s:GdbKill()
  endif
endfunction


function! nvimgdb#Spawn(backend, proxy_cmd, client_cmd)
  "Expand words in the client_cmd to support %, <word> etc
  let cmd = join(map(split(a:client_cmd), {k, v -> expand(v)}))
  call GdbInit(a:backend, a:proxy_cmd, cmd)

  " Initialize the UI commands, autocommands etc
  call nvimgdb#ui#Enter()
endfunction


function! nvimgdb#Kill()
  if !GdbCheckTab() | return | endif
  call s:GdbKill()
endfunction

let s:plugin_dir = expand('<sfile>:p:h:h')

function! nvimgdb#GetPluginDir()
  return s:plugin_dir
endfunction

function! nvimgdb#TermOpen(command, tab)
  return termopen(a:command,
    \ {'on_stdout': {j,d,e -> GdbParserFeed(a:tab, d)},
    \  'on_exit': {j,c,e -> execute('if c == 0 | close | endif')},
    \ })
endfunction
