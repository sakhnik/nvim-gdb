sign define GdbBreakpoint text=●
sign define GdbCurrentLine text=⇒


" Count of active debugging views
let g:nvimgdb_count = 0
let s:plugin_dir = expand('<sfile>:p:h:h')

" gdb specifics
let s:backend_gdb = {
  \ 'init': ['set confirm off',
  \          'set pagination off',
  \          'source ' . s:plugin_dir . '/lib/gdb_commands.py'],
  \ 'paused': [
  \     ['Continuing.', 'continue'],
  \     ['\v[\o32]{2}([^:]+):(\d+):\d+', 'jump'],
  \     ['\vBreakpoint (\d+) at ([^:]+): file ([^,]+), line (\d+).', 'breakpoint'],
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
  \ 'init': ['settings set frame-format frame #${frame.index}: ${frame.pc}{ ${module.file.basename}{`${function.name-with-args}{${frame.no-debug}${function.pc-offset}}}}{ at \032\032${line.file.fullpath}:${line.number}}{${function.is-optimized} [opt]}\n',
  \          'settings set auto-confirm true',
  \          'settings set stop-line-count-before 0',
  \          'settings set stop-line-count-after 0'],
  \ 'paused': [
  \     ['\v^Process \d+ resuming', 'continue'],
  \     ['\v at [\o32]{2}([^:]+):(\d+)', 'jump'],
  \     ['\vBreakpoint (\d+): where = (.+) at ([^:]+):(\d+)', 'breakpoint'],
  \ ],
  \ 'running': [
  \     ['\v^Breakpoint \d+:', 'pause'],
  \     ['\v^Process \d+ stopped', 'pause'],
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
  if t:gdb != self
    " Don't jump if we are not in the current debugger tab
    return
  endif
  let window = winnr()
  exe self._jump_window 'wincmd w'
  let self._current_buf = bufnr('%')
  let target_buf = bufnr(a:file, 1)
  if bufnr('%') != target_buf
    " Switch to the new buffer
    exe 'buffer ' target_buf
    let self._current_buf = target_buf
    call s:RefreshBreakpointSigns(self._current_buf)
  endif
  exe ':' a:line
  let self._current_line = a:line
  exe window 'wincmd w'
  call self.update_current_line_sign(1)
endfunction

" Transition "paused" -> "paused": jump to the frame location
function s:GdbPaused_breakpoint(num, skip, file, line, ...) dict
  if exists("self._pending_breakpoint_file")
    let file_name = self._pending_breakpoint_file
    let linenr = self._pending_breakpoint_linenr
    unlet self._pending_breakpoint_file
    unlet self._pending_breakpoint_linenr
  else
    let linenr = a:line
    let file_name = t:gdb._impl.FindSource(a:file)
    if empty(file_name)
      return
    endif
  endif

  " Remember the breakpoint number
  let file_breakpoints = get(self._breakpoints, file_name, {})
  let file_breakpoints[linenr] = a:num
  let self._breakpoints[file_name] = file_breakpoints

  " Update the breakpoint signs if the buffer is on screen
  let target_buf = bufnr(file_name)   " returns -1 if buffer doesn't exist
  if target_buf == bufnr('%')
    call s:RefreshBreakpointSigns(target_buf)
  endif
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
  let g:nvimgdb_count -= 1
  if !g:nvimgdb_count
    " Cleanup the autocommands
    augroup NvimGdb
      au!
    augroup END
    augroup! NvimGdb

    " Cleanup user commands and keymaps
    call s:UndefCommands()
  endif

  " Clean up the breakpoint signs
  let t:gdb._breakpoints = {}
  call s:ClearBreakpointSigns()

  " Clean up the current line sign
  call self.update_current_line_sign(0)

  " Close the windows and the tab
  tabclose
  if bufexists(self._client_buf)
    exe 'bd! '.self._client_buf
  endif

  " TabEnter isn't fired automatically when a tab is closed
  call s:OnTabEnter()
endfunction


function! s:Gdb.send(data)
  call jobsend(self._client_id, a:data."\<cr>")
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

" Define keymap local variable
" Parameters:
"   key_lvar    Local variable name to remember the mapping
"   key_gvar    Global variable name for users to override the mapping
"   key_def     Default key code
function! s:DefKeymapVar(key_lvar, key_gvar, key_def)
  if exists(a:key_gvar)
    exe 'let ' . a:key_lvar . ' = ' . a:key_gvar
  else
    exe 'let ' . a:key_lvar . ' = "' . a:key_def . '"'
  endif
endfunction

function! s:DefKeymapVars()
  " Set global key maps
  call s:DefKeymapVar("t:nvimgdb_key_continue",   "g:nvimgdb_key_continue",   "<f5>" )
  call s:DefKeymapVar("t:nvimgdb_key_next",       "g:nvimgdb_key_next",       "<f10>")
  call s:DefKeymapVar("t:nvimgdb_key_step",       "g:nvimgdb_key_step",       "<f11>")
  call s:DefKeymapVar("t:nvimgdb_key_finish",     "g:nvimgdb_key_finish",     "<f12>")

  call s:DefKeymapVar("t:nvimgdb_key_breakpoint", "g:nvimgdb_key_breakpoint", "<f8>" )
  call s:DefKeymapVar("t:nvimgdb_key_frameup",    "g:nvimgdb_key_frameup",    "<c-p>")
  call s:DefKeymapVar("t:nvimgdb_key_framedown",  "g:nvimgdb_key_framedown",  "<c-n>")
  call s:DefKeymapVar("t:nvimgdb_key_eval",       "g:nvimgdb_key_eval",       "<f9>" )
endfunction

function! s:SetKeymaps()
  exe 'nnoremap <buffer> <silent> ' . t:nvimgdb_key_continue . ' :GdbContinue<cr>'
  exe 'nnoremap <buffer> <silent> ' . t:nvimgdb_key_next . ' :GdbNext<cr>'
  exe 'nnoremap <buffer> <silent> ' . t:nvimgdb_key_step . ' :GdbStep<cr>'
  exe 'nnoremap <buffer> <silent> ' . t:nvimgdb_key_finish . ' :GdbFinish<cr>'

  exe 'nnoremap <buffer> <silent> ' . t:nvimgdb_key_breakpoint . ' :GdbBreakpointToggle<cr>'
  exe 'nnoremap <buffer> <silent> ' . t:nvimgdb_key_frameup . ' :GdbFrameUp<cr>'
  exe 'nnoremap <buffer> <silent> ' . t:nvimgdb_key_framedown . ' :GdbFrameDown<cr>'
  exe 'nnoremap <buffer> <silent> ' . t:nvimgdb_key_eval . ' :GdbEvalWord<cr>'

  exe 'vnoremap <buffer> <silent> ' . t:nvimgdb_key_eval . ' :GdbEvalRange<cr>'
endfunction

function! s:UnsetKeymaps()
  exe 'nunmap <buffer> ' . t:nvimgdb_key_continue
  exe 'nunmap <buffer> ' . t:nvimgdb_key_next
  exe 'nunmap <buffer> ' . t:nvimgdb_key_step
  exe 'nunmap <buffer> ' . t:nvimgdb_key_finish

  exe 'nunmap <buffer> ' . t:nvimgdb_key_breakpoint
  exe 'nunmap <buffer> ' . t:nvimgdb_key_frameup
  exe 'nunmap <buffer> ' . t:nvimgdb_key_framedown
  exe 'nunmap <buffer> ' . t:nvimgdb_key_eval

  exe 'vunmap <buffer> ' . t:nvimgdb_key_eval
endfunction

function! s:SetTKeymaps()
  " Set term-local key maps
  exe 'tnoremap <buffer> <silent> ' . t:nvimgdb_key_continue . ' <c-\><c-n>:GdbContinue<cr>i'
  exe 'tnoremap <buffer> <silent> ' . t:nvimgdb_key_next . ' <c-\><c-n>:GdbNext<cr>i'
  exe 'tnoremap <buffer> <silent> ' . t:nvimgdb_key_step . ' <c-\><c-n>:GdbStep<cr>i'
  exe 'tnoremap <buffer> <silent> ' . t:nvimgdb_key_finish . ' <c-\><c-n>:GdbFinish<cr>i'
  tnoremap <silent> <buffer> <esc> <c-\><c-n>

  " Set normal mode keymaps too
  call s:SetKeymaps()
endfunction


function! s:DefineCommands()
  command! GdbDebugStop call nvimgdb#Kill()
  command! GdbBreakpointToggle call nvimgdb#ToggleBreak()
  command! GdbBreakpointClearAll call nvimgdb#ClearBreak()
  command! GdbRun call nvimgdb#Send("run")
  command! GdbContinue call nvimgdb#Send("c")
  command! GdbNext call nvimgdb#Send("n")
  command! GdbStep call nvimgdb#Send("s")
  command! GdbFinish call nvimgdb#Send("finish")
  command! GdbFrameUp call nvimgdb#Send("up")
  command! GdbFrameDown call nvimgdb#Send("down")
  command! GdbInterrupt call nvimgdb#Interrupt()
  command! GdbEvalWord call nvimgdb#Eval(expand('<cword>'))
  command! -range GdbEvalRange call nvimgdb#Eval(s:GetExpression(<f-args>))
endfunction


function! s:UndefCommands()
  delcommand GdbDebugStop
  delcommand GdbBreakpointToggle
  delcommand GdbBreakpointClearAll
  delcommand GdbRun
  delcommand GdbContinue
  delcommand GdbNext
  delcommand GdbStep
  delcommand GdbFinish
  delcommand GdbFrameUp
  delcommand GdbFrameDown
  delcommand GdbInterrupt
  delcommand GdbEvalWord
  delcommand GdbEvalRange
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

  "  +-jump,breakpoint--+
  "  |                  |
  "  +-------------->PAUSED---continue--->RUNNING
  "                     |                   |
  "                     +<-----pause--------+
  "
  let data._state_paused = vimexpect#State(data.backend["paused"])
  let data._state_paused.continue = function("s:GdbPaused_continue", data)
  let data._state_paused.jump = function("s:GdbPaused_jump", data)
  let data._state_paused.breakpoint = function("s:GdbPaused_breakpoint", data)

  let data._state_running = vimexpect#State(data.backend["running"])
  let data._state_running.pause = function("s:GdbRunning_pause", data)

  return vimexpect#Parser(data._state_running, data)
endfunction


" The checks to be executed when navigating the windows
function! s:OnWinEnter()
  " If this isn't a debugging session, nothing to do
  if !exists('t:gdb') | return | endif

  " The tabpage should contain at least two windows, finish debugging
  " otherwise.
  if tabpagewinnr(tabpagenr(), '$') == 1
    call t:gdb.kill()
    return
  endif
endfunction

function! s:OnTabEnter()
  if !exists('t:gdb') | return | endif

  " Restore the signs as they may have been spoiled
  if t:gdb._parser.state() == t:gdb._state_paused
    call t:gdb.update_current_line_sign(1)
  endif
  call s:RefreshBreakpointSigns(t:gdb._current_buf)
endfunction

function! s:OnTabLeave()
  if !exists('t:gdb') | return | endif

  " Hide the signs
  call t:gdb.update_current_line_sign(0)
  call s:ClearBreakpointSigns()
endfunction


function! s:OnBufEnter()
  if !exists('t:gdb') | return | endif
  if &buftype ==# 'terminal' | return | endif
  call s:SetKeymaps()
endfunction

function! s:OnBufLeave()
  if !exists('t:gdb') | return | endif
  if &buftype ==# 'terminal' | return | endif
  call s:UnsetKeymaps()
endfunction


function! nvimgdb#Spawn(backend, proxy_cmd, client_cmd)
  let gdb = s:InitMachine(a:backend, s:Gdb)
  exe 'let gdb._impl = nvimgdb#' . a:backend . '#GetImpl()'
  let gdb._initialized = 0
  " window number that will be displaying the current file
  let gdb._jump_window = 1
  let gdb._current_buf = -1
  let gdb._current_line = -1
  let gdb._breakpoints = {}
  let gdb._max_breakpoint_sign_id = 0
  " Create new tab for the debugging view
  tabnew
  " create horizontal split to display the current file
  sp
  " go to the bottom window and spawn gdb client
  wincmd j

  " Prepare the debugger command to run
  let l:command = ''
  if a:proxy_cmd != ''
    let l:command = s:plugin_dir . '/lib/' . a:proxy_cmd . ' '
  endif
  let l:command .= a:client_cmd

  enew | let gdb._client_id = termopen(l:command, gdb)
  let gdb._client_buf = bufnr('%')
  let t:gdb = gdb

  " Check if user closed either of our windows.
  if !g:nvimgdb_count
    call s:DefineCommands()
    augroup NvimGdb
      au!
      au WinEnter * call s:OnWinEnter()
      au TabEnter * call s:OnTabEnter()
      au TabLeave * call s:OnTabLeave()
      au BufEnter * call s:OnBufEnter()
      au BufLeave * call s:OnBufLeave()
    augroup END
  endif
  let g:nvimgdb_count += 1

  call s:DefKeymapVars()
  call s:SetTKeymaps()
  " Start inset mode in the GDB window
  normal i
endfunction


" Breakpoints need full path to the buffer (at least in lldb)
function! s:GetFullBufferPath(buf)
  return expand('#' . a:buf . ':p')
endfunction


function! nvimgdb#ToggleBreak()
  if !exists('t:gdb') | return | endif

  if t:gdb._parser.state() == t:gdb._state_running
    " pause first
    call jobsend(t:gdb._client_id, "\<c-c>")
  endif

  let buf = bufnr('%')
  let file_name = s:GetFullBufferPath(buf)
  let file_breakpoints = get(t:gdb._breakpoints, file_name, {})
  let linenr = line('.')

  if has_key(file_breakpoints, linenr)
    " There already is a breakpoint on this line: remove
    call t:gdb.send(t:gdb.backend['delete_breakpoints'] . ' ' . file_breakpoints[linenr])
    call remove(file_breakpoints, linenr)
    " Finally, remember and update the breakpoint signs
    let t:gdb._breakpoints[file_name] = file_breakpoints
    call s:RefreshBreakpointSigns(buf)
  else
    " Add a new breakpoint
    let file_breakpoints[linenr] = 1
    let t:gdb._pending_breakpoint_file = file_name
    let t:gdb._pending_breakpoint_linenr = linenr
    call t:gdb.send(t:gdb.backend['breakpoint'] . ' ' . file_name . ':' . linenr)
    " Adding will be finished in the callback stopped::breakpoint
  endif
endfunction


function! nvimgdb#ClearBreak()
  if !exists('t:gdb') | return | endif

  let t:gdb._breakpoints = {}
  call s:ClearBreakpointSigns()

  if t:gdb._parser.state() == t:gdb._state_running
    " pause first
    call jobsend(t:gdb._client_id, "\<c-c>")
  endif
  call t:gdb.send(t:gdb.backend['delete_breakpoints'])
endfunction


function! s:ClearBreakpointSigns()
  let i = 5000
  while i <= t:gdb._max_breakpoint_sign_id
    exe 'sign unplace '.i
    let i += 1
  endwhile
  let t:gdb._max_breakpoint_sign_id = 0
endfunction

function! s:SetBreakpointSigns(buf)
  if a:buf == -1
    return
  endif
  let t:gdb._max_breakpoint_sign_id = 0
  let id = 5000
  for linenr in keys(get(t:gdb._breakpoints, s:GetFullBufferPath(a:buf), {}))
    exe 'sign place '.id.' name=GdbBreakpoint line='.linenr.' buffer='.a:buf
    let t:gdb._max_breakpoint_sign_id = id
    let id += 1
  endfor
endfunction

function! s:RefreshBreakpointSigns(buf)
  call s:ClearBreakpointSigns()
  call s:SetBreakpointSigns(a:buf)
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
  call t:gdb.send(a:data)
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
