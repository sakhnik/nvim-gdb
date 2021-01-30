
let s:plugin_dir = expand('<sfile>:p:h:h')

function! nvimgdb#GetPluginDir()
  return s:plugin_dir
endfunction

function! nvimgdb#TermOpen(command, tab)
  return termopen(a:command,
    \ {'on_stdout': {j,d,e -> luaeval("nvimgdb.parser_feed(_A[1], _A[2])", [a:tab, d])},
    \  'on_exit': {j,c,e -> execute('if c == 0 | silent! close! | endif')},
    \ })
endfunction

function! nvimgdb#ClearAugroup(name)
    exe "augroup " . a:name
      au!
    augroup END
    exe "augroup! " . a:name
endfunction


function! s:GetExpression(...) range
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][:col2 - 1]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, "\n")
endfunction


"Shared global state initialization (commands, keymaps etc)
function! nvimgdb#GlobalInit()
  command! GdbDebugStop lua nvimgdb.cleanup(vim.api.nvim_get_current_tabpage())
  command! GdbBreakpointToggle lua nvimgdb.i():breakpoint_toggle()
  command! GdbBreakpointClearAll lua nvimgdb.i():breakpoint_clear_all()
  command! GdbFrame lua nvimgdb.i():send('f')
  command! GdbRun lua nvimgdb.i():send('run')
  command! GdbUntil lua nvimgdb.i():send('until %s', vim.fn.line('.'))
  command! GdbContinue lua nvimgdb.i():send('c')
  command! GdbNext lua nvimgdb.i():send('n')
  command! GdbStep lua nvimgdb.i():send('s')
  command! GdbFinish lua nvimgdb.i():send('finish')
  command! GdbFrameUp lua nvimgdb.i():send('up')
  command! GdbFrameDown lua nvimgdb.i():send('down')
  command! GdbInterrupt lua nvimgdb.i():send()
  command! GdbEvalWord lua nvimgdb.i():send('print %s', vim.fn.expand('<cword>'))
  command! -range GdbEvalRange call luaeval("nvimgdb.i():send('print %s', _A[1])", [s:GetExpression(<f-args>)])
  command! -nargs=1 GdbCreateWatch call luaeval("nvimgdb.i():create_watch(_A[1])", [<q-args>])
  command! GdbLopenBacktrace call luaeval("nvimgdb.i():lopen('backtrace', '<mods>')")
  command! GdbLopenBreakpoints call luaeval("nvimgdb.i():lopen('breakpoints', '<mods>')")

  function! GdbCustomCommand(cmd)
    return luaeval("nvimgdb.i():custom_command(_A[1])", [a:cmd])
  endfunction

  augroup NvimGdb
    au!
    au TabEnter * lua nvimgdb.i(0):on_tab_enter()
    au TabLeave * lua nvimgdb.i(0):on_tab_leave()
    au BufEnter * lua nvimgdb.i(0):on_buf_enter()
    au BufLeave * lua nvimgdb.i(0):on_buf_leave()
    au TabClosed * lua nvimgdb.on_tab_closed()
    au VimLeavePre * lua nvimgdb.on_vim_leave_pre()
  augroup END

  " Define custom events
  augroup NvimGdbInternal
    au!
    au User NvimGdbQuery ""
    au User NvimGdbBreak ""
    au User NvimGdbContinue ""
    au User NvimGdbStart ""
    au User NvimGdbCleanup ""
  augroup END
endfunction

"Shared global state cleanup after the last session ended
function! nvimgdb#GlobalCleanup()
  " Cleanup the autocommands
  call nvimgdb#ClearAugroup("NvimGdb")
  " Cleanup custom events
  call nvimgdb#ClearAugroup("NvimGdbInternal")

  delfunction GdbCustomCommand

  " Cleanup user commands and keymaps
  delcommand GdbDebugStop
  delcommand GdbBreakpointToggle
  delcommand GdbBreakpointClearAll
  delcommand GdbFrame
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
  delcommand GdbCreateWatch
  delcommand GdbLopenBacktrace
  delcommand GdbLopenBreakpoints
endfunction
