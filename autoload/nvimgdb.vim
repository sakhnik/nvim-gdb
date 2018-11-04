sign define GdbBreakpoint text=●
sign define GdbCurrentLine text=⇒


" Count of active debugging views
let g:nvimgdb_count = 0
let s:plugin_dir = expand('<sfile>:p:h:h')

" Default configuration
let s:default_config = {
  \ 'key_until': '<f4>',
  \ 'key_continue': '<f5>',
  \ 'key_next': '<f10>',
  \ 'key_step': '<f11>',
  \ 'key_finish': '<f12>',
  \ 'key_breakpoint': '<f8>',
  \ 'key_frameup': '<c-p>',
  \ 'key_framedown': '<c-n>',
  \ 'key_eval': '<f9>',
  \ 'set_tkeymaps': function('nvimgdb#SetTKeymaps'),
  \ 'set_keymaps': function('nvimgdb#SetKeymaps'),
  \ 'unset_keymaps': function('nvimgdb#UnsetKeymaps'),
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
    call s:RefreshBreakpointSigns(self._current_buf)
  endif

  exe ':' a:line
  let self._current_line = a:line
  exe window 'wincmd w'
  call self.update_current_line_sign(1)
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
  let fname = s:GetFullBufferPath(bufnum)

  " If no file name or a weird name with spaces, ignore it (to avoid
  " misinterpretation)
  if fname == '' || stridx(fname, ' ') != -1
    return
  endif

  " Query the breakpoints for the shown file
  let breaks = s:InfoBreakpoints(fname, t:gdb._proxy_addr)
  if has_key(breaks, "_error")
    echo "Can't get breakpoints: " . breaks["_error"]
    return
  endif
  let self._breakpoints[fname] = breaks
  call s:RefreshBreakpointSigns(bufnum)
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

  " TODO: find a better way
  call t:gdb._state_paused.info_breakpoints()
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


let s:info_breakpoints_loaded = 0

function! s:InfoBreakpoints(file, proxy_addr)
  if !s:info_breakpoints_loaded
    exe 'py3file ' . s:plugin_dir . '/lib/info_breakpoints.py'
    let s:info_breakpoints_loaded = 1
  endif
  return json_decode(py3eval("InfoBreakpoints('" . a:file . "', '" . a:proxy_addr . "')"))
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

let s:default_keymaps = [
  \ ['n', 'key_until', ':GdbUntil'],
  \ ['n', 'key_continue', ':GdbContinue'],
  \ ['n', 'key_next', ':GdbNext'],
  \ ['n', 'key_step', ':GdbStep'],
  \ ['n', 'key_finish', ':GdbFinish'],
  \ ['n', 'key_breakpoint', ':GdbBreakpointToggle'],
  \ ['n', 'key_frameup', ':GdbFrameUp'],
  \ ['n', 'key_framedown', ':GdbFrameDown'],
  \ ['n', 'key_eval', ':GdbEvalWord'],
  \ ['v', 'key_eval', ':GdbEvalRange'],
  \ ]

function! nvimgdb#SetKeymaps()
  for keymap in s:default_keymaps
    if has_key(t:config, keymap[1])
      let key = t:config[keymap[1]]
      if !empty(key)
        exe keymap[0] . 'noremap <buffer> <silent> ' . key . ' ' . keymap[2]'<cr>'
      endif
    endif
  endfor
endfunction

function! nvimgdb#UnsetKeymaps()
  for keymap in s:default_keymaps
    if has_key(t:config, keymap[1])
      let key = t:config[keymap[1]]
      if !empty(key)
        exe keymap[0] . 'unmap <buffer> ' . key
      endif
    endif
  endfor
endfunction

let s:default_tkeymaps = [
  \ ['key_until', ':GdbUntil'],
  \ ['key_continue', ':GdbContinue'],
  \ ['key_next', ':GdbNext'],
  \ ['key_step', ':GdbStep'],
  \ ['key_finish', ':GdbFinish'],
  \ ]

function! nvimgdb#SetTKeymaps()
  " Set term-local key maps
  for keymap in s:default_tkeymaps
    if has_key(t:config, keymap[0])
      let key = t:config[keymap[0]]
      if !empty(key)
        exe 'tnoremap <buffer> <silent> ' . key . ' <c-\><c-n>' . keymap[1] . '<cr>i'
      endif
    endif
  endfor
  tnoremap <silent> <buffer> <esc> <c-\><c-n>
endfunction


function! s:DefineCommands()
  command! GdbDebugStop call nvimgdb#Kill()
  command! GdbBreakpointToggle call nvimgdb#ToggleBreak()
  command! GdbBreakpointClearAll call nvimgdb#ClearBreak()
  command! GdbRun call nvimgdb#Send("run")
  command! GdbUntil call nvimgdb#Send(t:gdb.backend["until"] . " " . line('.'))
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
  delcommand GdbUntil
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

function! s:OnTabEnter()
  if !exists('t:gdb') | return | endif

  " Restore the signs as they may have been spoiled
  if t:gdb._parser.state() == t:gdb._state_paused
    call t:gdb.update_current_line_sign(1)
  endif

  " Ensure breakpoints are shown if are queried dynamically
  call t:gdb._state_paused.info_breakpoints()
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
  try
    call t:config['set_keymaps']()
  endtry
  " Ensure breakpoints are shown if are queried dynamically
  call t:gdb._state_paused.info_breakpoints()
endfunction

function! s:OnBufLeave()
  if !exists('t:gdb') | return | endif
  if &buftype ==# 'terminal' | return | endif
  try
    call t:config['unset_keymaps']()
  endtry
endfunction


function! s:InitConfig()
  " Make a copy of the supplied configuration if defined
  if exists('g:nvimgdb_config')
    let config = copy(g:nvimgdb_config)
  else
    let config = copy(s:default_config)
  endif

  " If there is config override defined, add it
  if exists('g:nvimgdb_config_override')
    call extend(config, g:nvimgdb_config_override)
  endif

  " See whether a global override for a specific configuration
  " key exists. If so, update the config.
  for key in keys(config)
    let varname = 'g:nvimgdb_' . key
    if exists(varname)
      let config[key] = eval(varname)
    endif
  endfor

  " Return the resulting configuration
  return config
endfunction


function! nvimgdb#Spawn(backend, proxy_cmd, client_cmd)
  let gdb = s:InitMachine(a:backend, s:Gdb)
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
  let t:config = s:InitConfig()

  " Check if user closed either of our windows.
  if !g:nvimgdb_count
    call s:DefineCommands()
    augroup NvimGdb
      au!
      " Unfortunately, there is no event to handle a window closed.
      " It's needed to be handled heuristically:
      "   When :quit is executed, the cursor will enter another buffer
      au WinEnter * call nvimgdb#CheckWindowClosed()
      "   When :only is executed, BufWinLeave will be issued before closing
      "   window. We start a timer expecting it to expire after the window
      "   has been closed. It's a race.
      au BufWinLeave * call timer_start(100, "nvimgdb#CheckWindowClosed")
      au TabEnter * call s:OnTabEnter()
      au TabLeave * call s:OnTabLeave()
      au BufEnter * call s:OnBufEnter()
      au BufLeave * call s:OnBufLeave()
    augroup END
  endif
  let g:nvimgdb_count += 1

  " Set terminal window keymaps
  try
    call t:config['set_tkeymaps']()
  endtry

  " Set normal mode keymaps too
  try
    call t:config['set_keymaps']()
  endtry

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
  else
    call t:gdb.send(t:gdb.backend['breakpoint'] . ' ' . file_name . ':' . linenr)
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
  let t:gdb._max_breakpoint_sign_id = 5000 - 1
  for linenr in keys(get(t:gdb._breakpoints, s:GetFullBufferPath(a:buf), {}))
    let t:gdb._max_breakpoint_sign_id += 1
    exe 'sign place '.t:gdb._max_breakpoint_sign_id.' name=GdbBreakpoint line='.linenr.' buffer='.a:buf
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
