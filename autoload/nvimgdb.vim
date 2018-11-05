

let s:plugin_dir = expand('<sfile>:p:h:h')


" Transition "paused" -> "continue"
function s:GdbPaused_continue(...) dict
  call self._parser.switch(self._state_running)
  call nvimgdb#cursor#display(0)
endfunction


" Transition "paused" -> "paused": jump to the frame location
function s:GdbPaused_jump(file, line, ...) dict
  if t:gdb != self
    " Don't jump if we are not in the current debugger tab
    return
  endif
  let window = winnr()
  exe self._jump_window 'wincmd w'
  let self._current_buf = bufnr('%')
  let target_buf = bufnr(a:file, 1)
  if target_buf == self._client_buf
    " The terminal buffer may contain the name of the source file (in pdb, for
    " instance)
    exe "e " . a:file
    let target_buf = bufnr(a:file)
  endif

  if bufnr('%') != target_buf
    " Switch to the new buffer
    exe 'buffer ' target_buf
    let self._current_buf = target_buf
    call nvimgdb#breakpoint#refresh(self._current_buf)
  endif

  exe ':' a:line
  call nvimgdb#cursor#set(a:line)
  exe window 'wincmd w'
  call nvimgdb#cursor#display(1)
endfunction

" Transition "paused" -> "paused": refresh breakpoints in the current file
function s:GdbPaused_info_breakpoints(...) dict
  if t:gdb != self
    " Don't do anything if we are not in the current debugger tab
    return
  endif

  " Get the source code buffer number
  if bufnr('%') == self._client_buf
    " The debugger terminal window is currently focused, so perform a couple
    " of jumps.
    let window = winnr()
    exe self._jump_window 'wincmd w'
    let bufnum = bufnr('%')
    exe window 'wincmd w'
  else
    let bufnum = bufnr('%')
  endif
  " Get the source code file name
  let fname = nvimgdb#GetFullBufferPath(bufnum)

  " If no file name or a weird name with spaces, ignore it (to avoid
  " misinterpretation)
  if fname == '' || stridx(fname, ' ') != -1
    return
  endif

  " Query the breakpoints for the shown file
  call nvimgdb#breakpoint#query(bufnum, fname, t:gdb._proxy_addr)

  call nvimgdb#cursor#display(1)
endfunction

" Transition "running" -> "pause"
function s:GdbRunning_pause(...) dict
  call self._parser.switch(self._state_paused)

  " TODO: find a better way
  call t:gdb._state_paused.info_breakpoints()
endfunction


let s:Gdb = {}


function s:Gdb.kill()

  " Cleanup commands, autocommands etc
  call nvimgdb#ui#Leave()

  " Clean up the breakpoint signs
  call nvimgdb#breakpoint#cleanup()

  " Clean up the current line sign
  call nvimgdb#cursor#display(0)

  " Close the windows and the tab
  tabclose
  if bufexists(self._client_buf)
    exe 'bd! '.self._client_buf
  endif

  " TabEnter isn't fired automatically when a tab is closed
  call nvimgdb#OnTabEnter()
endfunction


function! s:Gdb.send(data)
  call jobsend(self._client_id, a:data."\<cr>")
endfunction


" Initialize the state machine depending on the chosen backend.
function! s:InitMachine(backend, struct)
  let data = copy(a:struct)

  " Identify and select the appropriate backend
  let data.backend = nvimgdb#backend#{a:backend}#create()

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
    return
  endif
endfunction

function! nvimgdb#OnTabEnter()
  if !exists('t:gdb') | return | endif

  " Restore the signs as they may have been spoiled
  if t:gdb._parser.state() == t:gdb._state_paused
    call nvimgdb#cursor#display(1)
  endif

  " Ensure breakpoints are shown if are queried dynamically
  call t:gdb._state_paused.info_breakpoints()
endfunction

function! nvimgdb#OnTabLeave()
  if !exists('t:gdb') | return | endif

  " Hide the signs
  call nvimgdb#cursor#display(0)
  call nvimgdb#breakpoint#clear()
endfunction


function! nvimgdb#OnBufEnter()
  if !exists('t:gdb') | return | endif
  if &buftype ==# 'terminal' | return | endif
  call nvimgdb#keymaps#DispatchSet()
  " Ensure breakpoints are shown if are queried dynamically
  call t:gdb._state_paused.info_breakpoints()
endfunction

function! nvimgdb#OnBufLeave()
  if !exists('t:gdb') | return | endif
  if &buftype ==# 'terminal' | return | endif
  call nvimgdb#keymaps#DispatchUnset()
endfunction


function! nvimgdb#Spawn(backend, proxy_cmd, client_cmd)
  let gdb = s:InitMachine(a:backend, s:Gdb)
  " window number that will be displaying the current file
  let gdb._jump_window = 1
  let gdb._current_buf = -1
  " Create new tab for the debugging view
  tabnew
  " create horizontal split to display the current file
  sp

  " Initialize current line tracking
  call nvimgdb#cursor#init()

  " Initialize breakpoint tracking
  call nvimgdb#breakpoint#init()

  if !&scrolloff
    " Make sure the cursor stays visible at all times
    setlocal scrolloff=5
  endif

  " go to the bottom window and spawn gdb client
  wincmd j

  " Prepare the debugger command to run
  let l:command = ''
  if a:proxy_cmd != ''
    let gdb._proxy_addr = tempname()
    let l:command = s:plugin_dir . '/lib/' . a:proxy_cmd . ' -a ' . gdb._proxy_addr . ' -- '
  endif
  let l:command .= a:client_cmd

  enew | let gdb._client_id = termopen(l:command, gdb)
  let gdb._client_buf = bufnr('%')
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


function! nvimgdb#GetCurrentBuffer()
  return t:gdb._current_buf
endfunction


function! nvimgdb#ToggleBreak()
  if !exists('t:gdb') | return | endif

  if t:gdb._parser.state() == t:gdb._state_running
    " pause first
    call jobsend(t:gdb._client_id, "\<c-c>")
  endif

  let buf = bufnr('%')
  let file_name = nvimgdb#GetFullBufferPath(buf)
  let file_breakpoints = nvimgdb#breakpoint#get_for_file(file_name)
  let linenr = line('.')

  if has_key(file_breakpoints, linenr)
    " There already is a breakpoint on this line: remove
    call t:gdb.send(t:gdb.backend['delete_breakpoints'] . ' ' . file_breakpoints[linenr])
  else
    call t:gdb.send(t:gdb.backend['breakpoint'] . ' ' . file_name . ':' . linenr)
  endif
endfunction


function! nvimgdb#ClearBreak()
  if !exists('t:gdb') | return | endif

  call nvimgdb#breakpoint#cleanup()

  if t:gdb._parser.state() == t:gdb._state_running
    " pause first
    call jobsend(t:gdb._client_id, "\<c-c>")
  endif
  call t:gdb.send(t:gdb.backend['delete_breakpoints'])
endfunction


function! s:GetExpression(...) range
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][:col2 - 1]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, "\n")
endfunction


function! nvimgdb#Send(data)
  if !exists('t:gdb') | return | endif
  if has_key(t:gdb.backend, a:data)
    call t:gdb.send(t:gdb.backend[a:data])
  else
    call t:gdb.send(a:data)
  endif
endfunction


function! nvimgdb#Eval(expr)
  call nvimgdb#Send(printf('print %s', a:expr))
endfunction


function! nvimgdb#Interrupt()
  if !exists('t:gdb') | return | endif
  call jobsend(t:gdb._client_id, "\<c-c>")
endfunction


function! nvimgdb#Kill()
  if !exists('t:gdb') | return | endif
  call t:gdb.kill()
endfunction
