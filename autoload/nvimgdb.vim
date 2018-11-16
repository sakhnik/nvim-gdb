

" Transition "paused" -> "continue"
function s:GdbPaused_continue(...) dict
  if t:gdb != self | return | endif
  call self._parser.switch(self._state_running)
  call nvimgdb#cursor#Hide()
endfunction


" Transition "paused" -> "paused": jump to the frame location
function s:GdbPaused_jump(file, line, ...) dict
  if t:gdb != self | return | endif
  call nvimgdb#win#Jump(a:file, a:line)
endfunction

" Transition "paused" -> "paused": refresh breakpoints in the current file
function s:GdbPaused_info_breakpoints(...) dict
  if t:gdb != self | return | endif
  call nvimgdb#win#QueryBreakpoints()
endfunction

" Transition "running" -> "pause"
function s:GdbRunning_pause(...) dict
  if t:gdb != self | return | endif
  call self._parser.switch(self._state_paused)
  call nvimgdb#win#QueryBreakpoints()
endfunction


let s:Gdb = {}


function s:Gdb.kill()

  " Cleanup commands, autocommands etc
  call nvimgdb#ui#Leave()

  " Clean up the breakpoint signs
  call nvimgdb#breakpoint#Cleanup()

  " Clean up the current line sign
  call nvimgdb#cursor#Hide()

  call nvimgdb#win#Cleanup()

  " Close the windows and the tab
  let tabnr = tabpagenr('$')
  let client_buf = nvimgdb#client#GetBuf()
  if bufexists(client_buf)
    exe 'bd! '.client_buf
  endif
  if tabnr == tabpagenr('$')
    tabclose
  endif

  " TabEnter isn't fired automatically when a tab is closed
  call nvimgdb#OnTabEnter()
endfunction


" Initialize the state machine depending on the chosen backend.
function! s:InitMachine(backend, struct)
  let data = copy(a:struct)

  " Identify and select the appropriate backend
  let data.backend = nvimgdb#backend#{a:backend}#Get()

  "  +-jump,breakpoint--+
  "  |                  |
  "  +-------------->PAUSED---continue--->RUNNING
  "                     |                   |
  "                     +<-----pause--------+
  "
  let data._state_paused = vimexpect#State(data.backend["paused"])
  let data._state_paused.continue = function("s:GdbPaused_continue", data)
  let data._state_paused.jump = function("s:GdbPaused_jump", data)
  let data._state_paused.info_breakpoints = function("s:GdbPaused_info_breakpoints", data)

  let data._state_running = vimexpect#State(data.backend["running"])
  let data._state_running.pause = function("s:GdbRunning_pause", data)

  let init_state = eval('data._state_' . data.backend["init_state"])
  return vimexpect#Parser(init_state, data)
endfunction


" The checks to be executed when navigating the windows
function! nvimgdb#CheckWindowClosed(...)
  " If this isn't a debugging session, nothing to do
  if !exists('t:gdb') | return | endif

  " The tabpage should contain at least two windows, finish debugging
  " otherwise.
  if tabpagewinnr(tabpagenr(), '$') == 1
    call t:gdb.kill()
  endif
endfunction

function! nvimgdb#OnTabEnter()
  if !exists('t:gdb') | return | endif

  " Restore the signs as they may have been spoiled
  if t:gdb._parser.state() == t:gdb._state_paused
    call nvimgdb#cursor#Show()
  endif

  " Ensure breakpoints are shown if are queried dynamically
  call nvimgdb#win#QueryBreakpoints()
endfunction

function! nvimgdb#OnTabLeave()
  if !exists('t:gdb') | return | endif

  " Hide the signs
  call nvimgdb#cursor#Hide()
  call nvimgdb#breakpoint#Clear()
endfunction


function! nvimgdb#OnBufEnter()
  if !exists('t:gdb') | return | endif
  if &buftype ==# 'terminal' | return | endif
  call nvimgdb#keymaps#DispatchSet()
  " Ensure breakpoints are shown if are queried dynamically
  call nvimgdb#win#QueryBreakpoints()
endfunction

function! nvimgdb#OnBufLeave()
  if !exists('t:gdb') | return | endif
  if &buftype ==# 'terminal' | return | endif
  call nvimgdb#keymaps#DispatchUnset()
endfunction


function! nvimgdb#Spawn(backend, proxy_cmd, client_cmd)
  let gdb = s:InitMachine(a:backend, s:Gdb)
  " Create new tab for the debugging view
  tabnew
  " create horizontal split to display the current file
  sp

  " Initialize the windowing subsystem
  call nvimgdb#win#Init()

  " Initialize current line tracking
  call nvimgdb#cursor#Init()

  " Initialize breakpoint tracking
  call nvimgdb#breakpoint#Init()

  if !&scrolloff
    " Make sure the cursor stays visible at all times
    setlocal scrolloff=5
  endif

  " go to the bottom window and spawn gdb client
  wincmd j

  call nvimgdb#client#Init(a:proxy_cmd, a:client_cmd, gdb)

  let t:gdb = gdb

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


" Breakpoints need full path to the buffer (at least in lldb)
function! nvimgdb#GetFullBufferPath(buf)
  return expand('#' . a:buf . ':p')
endfunction

function! nvimgdb#ToggleBreak()
  if !exists('t:gdb') | return | endif

  if t:gdb._parser.state() == t:gdb._state_running
    " pause first
    call nvimgdb#client#Interrupt()
  endif

  let buf = bufnr('%')
  let file_name = nvimgdb#GetFullBufferPath(buf)
  let file_breakpoints = nvimgdb#breakpoint#GetForFile(file_name)
  let linenr = line('.')

  if has_key(file_breakpoints, linenr)
    " There already is a breakpoint on this line: remove
    call nvimgdb#client#SendLine(t:gdb.backend['delete_breakpoints'] . ' ' . file_breakpoints[linenr])
  else
    call nvimgdb#client#SendLine(t:gdb.backend['breakpoint'] . ' ' . file_name . ':' . linenr)
  endif
endfunction


function! nvimgdb#ClearBreak()
  if !exists('t:gdb') | return | endif

  call nvimgdb#breakpoint#Cleanup()

  if t:gdb._parser.state() == t:gdb._state_running
    " pause first
    call nvimgdb#client#Interrupt()
  endif
  call nvimgdb#client#SendLine(t:gdb.backend['delete_breakpoints'])
endfunction


function! nvimgdb#Send(data)
  if !exists('t:gdb') | return | endif
  call nvimgdb#client#SendLine(get(t:gdb.backend, a:data, a:data))
endfunction


function! nvimgdb#Eval(expr)
  call nvimgdb#Send(printf('print %s', a:expr))
endfunction


function! nvimgdb#Interrupt()
  if !exists('t:gdb') | return | endif
  call nvimgdb#client#Interrupt()
endfunction


function! nvimgdb#Kill()
  if !exists('t:gdb') | return | endif
  call t:gdb.kill()
endfunction
