sign define GdbBreakpoint text=●
sign define GdbCurrentLine text=⇒


let s:breakpoints = {}
let s:max_breakpoint_sign_id = 0

" gdb specifics
let s:backend_gdb = {
  \ 'init': ['set confirm off', 'set pagination off'],
  \ 'paused': [
  \     ['Continuing.', 'continue'],
  \     ['\v[\o32]{2}([^:]+):(\d+):\d+', 'jump'],
  \ ],
  \ 'running': [
  \     ['\v^Breakpoint \d+', 'pause'],
  \     ['\v hit Breakpoint \d+', 'pause'],
  \     ['(gdb)', 'pause'],
  \ ],
  \ 'delete_breakpoints': 'delete',
  \ 'breakpoint': 'break',
  \ }

" lldb specifics
let s:backend_lldb = {
  \ 'init': ['settings set frame-format \032\032${line.file.fullpath}:${line.number}:0\n',
  \          'settings set auto-confirm true',
  \          'settings set stop-line-count-before 0',
  \          'settings set stop-line-count-after 0'],
  \ 'paused': [
  \     ['\v^Process \d+ resuming$', 'continue'],
  \     ['\v[\o32]{2}([^:]+):(\d+):\d+', 'jump'],
  \ ],
  \ 'running': [
  \     ['\v^Breakpoint \d+:', 'pause'],
  \     ['\v^Process \d+ stopped$', 'pause'],
  \     ['(lldb)', 'pause'],
  \ ],
  \ 'delete_breakpoints': 'breakpoint delete',
  \ 'breakpoint': 'b',
  \ }


" Transition "paused" -> "continue"
function s:GdbPaused_continue(...) dict
  call self._parser.switch(self._state_running)
  call self.update_current_line_sign(0)
endfunction


" Transition "paused" -> "paused": jump to the frame location
function s:GdbPaused_jump(file, line, ...) dict
  if tabpagenr() != self._tab
    " Don't jump if we are not in the debugger tab
    return
  endif
  let window = winnr()
  exe self._jump_window 'wincmd w'
  let self._current_buf = bufnr('%')
  let target_buf = bufnr(a:file, 1)
  if bufnr('%') != target_buf
    exe 'buffer ' target_buf
    let self._current_buf = target_buf
  endif
  exe ':' a:line
  let self._current_line = a:line
  exe window 'wincmd w'
  call self.update_current_line_sign(1)
endfunction


" Transition "running" -> "pause"
function s:GdbRunning_pause(...) dict
  call self._parser.switch(self._state_paused)

  " For the first time the backend is paused, make sure it's initialized
  " appropriately. We are sure the interpreter is ready to handle commands now.
  if !self._initialized
    for c in self.backend["init"]
      call self.send(c)
    endfor
    let self._initialized = 1
  endif
endfunction


let s:Gdb = {}


function s:Gdb.kill()
  call s:UnsetKeymaps()
  call self.update_current_line_sign(0)
  exe 'bd! '.self._client_buf
  exe 'tabnext '.self._tab
  tabclose
  unlet g:gdb
endfunction


function! s:Gdb.send(data)
  call chansend(self._client_id, a:data."\<cr>")
endfunction



function! s:Gdb.update_current_line_sign(add)
  " to avoid flicker when removing/adding the sign column(due to the change in
  " line width), we switch ids for the line sign and only remove the old line
  " sign after marking the new one
  let old_line_sign_id = get(self, '_line_sign_id', 4999)
  let self._line_sign_id = old_line_sign_id == 4999 ? 4998 : 4999
  if a:add && self._current_line != -1 && self._current_buf != -1
    exe 'sign place '.self._line_sign_id.' name=GdbCurrentLine line='
          \.self._current_line.' buffer='.self._current_buf
  endif
  exe 'sign unplace '.old_line_sign_id
endfunction

function! s:SetKeymaps()
  if exists("g:nvimgdb_key_continue")
    let s:key_continue = g:nvimgdb_key_continue
  else
    let s:key_continue = '<f5>'
  endif

  exe 'nnoremap <silent> '.s:key_continue.' :GdbContinue<cr>'
  exe 'tnoremap <silent> '.s:key_continue.' <c-\><c-n>:GdbContinue<cr>i'

  if exists("g:nvimgdb_key_next")
    let s:key_next = g:nvimgdb_key_next
  else
    let s:key_next = '<f10>'
  endif

  exe 'nnoremap <silent> '.s:key_next.' :GdbNext<cr>'
  exe 'tnoremap <silent> '.s:key_next.' <c-\><c-n>:GdbNext<cr>i'

  if exists("g:nvimgdb_key_step")
    let s:key_step = g:nvimgdb_key_step
  else
    let s:key_step = '<f11>'
  endif

  exe 'nnoremap <silent> '.s:key_step.' :GdbStep<cr>'
  exe 'tnoremap <silent> '.s:key_step.' <c-\><c-n>:GdbStep<cr>i'

  if exists("g:nvimgdb_key_finish")
    let s:key_finish = g:nvimgdb_key_finish
  else
    let s:key_finish = '<f12>'
  endif

  exe 'nnoremap <silent> '.s:key_finish.' :GdbFinish<cr>'
  exe 'tnoremap <silent> '.s:key_finish.' <c-\><c-n>:GdbFinish<cr>i'

  if exists("g:nvimgdb_key_breakpoint")
    let s:key_breakpoint = g:nvimgdb_key_breakpoint
  else
    let s:key_breakpoint = '<f8>'
  endif

  exe 'nnoremap <silent> '.s:key_breakpoint.' :GdbToggleBreakpoint<cr>'

  if exists("g:nvimgdb_key_frameup")
    let s:key_frameup = g:nvimgdb_key_frameup
  else
    let s:key_frameup = '<c-p>'
  endif

  exe 'nnoremap <silent> '.s:key_frameup.' :GdbFrameUp<cr>'

  if exists("g:nvimgdb_key_framedown")
    let s:key_framedown = g:nvimgdb_key_framedown
  else
    let s:key_framedown = '<c-n>'
  endif

  exe 'nnoremap <silent> '.s:key_framedown.' :GdbFrameDown<cr>'

  if exists("g:nvimgdb_key_eval")
    let s:key_eval = g:nvimgdb_key_eval
  else
    let s:key_eval = '<f9>'
  endif

  exe 'nnoremap <silent> '.s:key_eval.' :GdbEvalWord<cr>'
  exe 'vnoremap <silent> '.s:key_eval.' :GdbEvalRange<cr>'

  tnoremap <silent> <buffer> <esc> <c-\><c-n>
endfunction

function! s:UnsetKeymaps()
  exe 'tunmap '.s:key_continue
  exe 'nunmap '.s:key_continue
  exe 'tunmap '.s:key_next
  exe 'nunmap '.s:key_next
  exe 'tunmap '.s:key_step
  exe 'nunmap '.s:key_step
  exe 'tunmap '.s:key_finish
  exe 'nunmap '.s:key_finish
  exe 'nunmap '.s:key_breakpoint
  exe 'nunmap '.s:key_frameup
  exe 'nunmap '.s:key_framedown
  exe 'nunmap '.s:key_eval
  exe 'vunmap '.s:key_eval
endfunction


" Initialize the state machine depending on the chosen backend.
function! s:InitMachine(backend, struct)
  let data = copy(a:struct)

  " Identify and select the appropriate backend
  if a:backend == "lldb"
    let data.backend = s:backend_lldb
  else
    " Fall back to GDB
    let data.backend = s:backend_gdb
  endif

  "  +-jump--+
  "  |       |
  "  +--->PAUSED---continue--->RUNNING
  "          |                   |
  "          +<-----pause--------+
  "
  let data._state_paused = vimexpect#State(data.backend["paused"])
  let data._state_paused.continue = function("s:GdbPaused_continue", data)
  let data._state_paused.jump = function("s:GdbPaused_jump", data)

  let data._state_running = vimexpect#State(data.backend["running"])
  let data._state_running.pause = function("s:GdbRunning_pause", data)

  return vimexpect#Parser(data._state_running, data)
endfunction


function! nvimgdb#Spawn(backend, client_cmd)
  if exists('g:gdb')
    throw 'Gdb already running'
  endif

  let gdb = s:InitMachine(a:backend, s:Gdb)
  let gdb._initialized = 0
  " window number that will be displaying the current file
  let gdb._jump_window = 1
  let gdb._current_buf = -1
  let gdb._current_line = -1
  let gdb._has_breakpoints = 0 
  " Create new tab for the debugging view
  tabnew
  let gdb._tab = tabpagenr()
  " create horizontal split to display the current file
  sp
  " go to the bottom window and spawn gdb client
  wincmd j
  enew | let gdb._client_id = termopen(a:client_cmd, gdb)
  let gdb._client_buf = bufnr('%')
  call s:SetKeymaps()
  " Start inset mode in the GDB window
  normal i
  let g:gdb = gdb
endfunction


" Breakpoints need full path to the buffer (at least in lldb)
function! s:GetCurrentFilePath()
  return expand('%:p')
endfunction


function! nvimgdb#ToggleBreak()
  let file_name = s:GetCurrentFilePath()
  let file_breakpoints = get(s:breakpoints, file_name, {})
  let linenr = line('.')
  if has_key(file_breakpoints, linenr)
    call remove(file_breakpoints, linenr)
  else
    let file_breakpoints[linenr] = 1
  endif
  let s:breakpoints[file_name] = file_breakpoints
  call s:RefreshBreakpointSigns()
  call s:RefreshBreakpoints()
endfunction


function! nvimgdb#ClearBreak()
  let s:breakpoints = {}
  call s:RefreshBreakpointSigns()
  call s:RefreshBreakpoints()
endfunction


function! s:RefreshBreakpointSigns()
  let buf = bufnr('%')
  let i = 5000
  while i <= s:max_breakpoint_sign_id
    exe 'sign unplace '.i
    let i += 1
  endwhile
  let s:max_breakpoint_sign_id = 0
  let id = 5000
  for linenr in keys(get(s:breakpoints, s:GetCurrentFilePath(), {}))
    exe 'sign place '.id.' name=GdbBreakpoint line='.linenr.' buffer='.buf
    let s:max_breakpoint_sign_id = id
    let id += 1
  endfor
endfunction


function! s:RefreshBreakpoints()
  if !exists('g:gdb')
    return
  endif
  if g:gdb._parser.state() == g:gdb._state_running
    " pause first
    call jobsend(g:gdb._client_id, "\<c-c>")
  endif
  if g:gdb._has_breakpoints
    call g:gdb.send(g:gdb.backend['delete_breakpoints'])
  endif
  let g:gdb._has_breakpoints = 0
  for [file, breakpoints] in items(s:breakpoints)
    for linenr in keys(breakpoints)
      let g:gdb._has_breakpoints = 1
      call g:gdb.send(g:gdb.backend['breakpoint'].' '.file.':'.linenr)
    endfor
  endfor
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
  if !exists('g:gdb')
    throw 'Gdb is not running'
  endif
  call g:gdb.send(a:data)
endfunction


function! nvimgdb#Eval(expr)
  call nvimgdb#Send(printf('print %s', a:expr))
endfunction


function! nvimgdb#Interrupt()
  if !exists('g:gdb')
    throw 'Gdb is not running'
  endif
  call jobsend(g:gdb._client_id, "\<c-c>info line\<cr>")
endfunction


function! nvimgdb#Kill()
  if !exists('g:gdb')
    throw 'Gdb is not running'
  endif
  call g:gdb.kill()
endfunction


command! GdbDebugStop call nvimgdb#Kill()
command! GdbToggleBreakpoint call nvimgdb#ToggleBreak()
command! GdbClearBreakpoints call nvimgdb#ClearBreak()
command! GdbContinue call nvimgdb#Send("c")
command! GdbNext call nvimgdb#Send("n")
command! GdbStep call nvimgdb#Send("s")
command! GdbFinish call nvimgdb#Send("finish")
command! GdbFrameUp call nvimgdb#Send("up")
command! GdbFrameDown call nvimgdb#Send("down")
command! GdbInterrupt call nvimgdb#Interrupt()
command! GdbEvalWord call nvimgdb#Eval(expand('<cword>'))
command! -range GdbEvalRange call nvimgdb#Eval(s:GetExpression(<f-args>))
