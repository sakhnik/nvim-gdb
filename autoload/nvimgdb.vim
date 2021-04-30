
function! nvimgdb#TermOpen(command, tab)
  return termopen(a:command,
    \ {'on_stdout': {j,d,e -> luaeval("NvimGdb.parser_feed(_A[1], _A[2])", [a:tab, d])},
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
  command! GdbDebugStop lua NvimGdb.cleanup(vim.api.nvim_get_current_tabpage())
  command! GdbBreakpointToggle lua NvimGdb.i():breakpoint_toggle()
  command! GdbBreakpointClearAll lua NvimGdb.i():breakpoint_clear_all()
  command! GdbFrame lua NvimGdb.i():send('f')
  command! GdbRun lua NvimGdb.i():send('run')
  command! GdbUntil lua NvimGdb.i():send('until %s', NvimGdb.vim.fn.line('.'))
  command! GdbContinue lua NvimGdb.i():send('c')
  command! GdbNext lua NvimGdb.i():send('n')
  command! GdbStep lua NvimGdb.i():send('s')
  command! GdbFinish lua NvimGdb.i():send('finish')
  command! GdbFrameUp lua NvimGdb.i():send('up')
  command! GdbFrameDown lua NvimGdb.i():send('down')
  command! GdbInterrupt lua NvimGdb.i():send()
  command! GdbEvalWord lua NvimGdb.i():send('print %s', NvimGdb.vim.fn.expand('<cword>'))
  command! -range GdbEvalRange call luaeval("NvimGdb.i():send('print %s', _A[1])", [s:GetExpression(<f-args>)])
  command! -nargs=1 GdbCreateWatch call luaeval("NvimGdb.i():create_watch(_A[1])", [<q-args>])
  command! GdbLopenBacktrace call luaeval("NvimGdb.i():lopen('backtrace', '<mods>')")
  command! GdbLopenBreakpoints call luaeval("NvimGdb.i():lopen('breakpoints', '<mods>')")

  function! GdbCustomCommand(cmd)
    return luaeval("NvimGdb.i():custom_command(_A[1])", [a:cmd])
  endfunction

  augroup NvimGdb
    au!
    au TabEnter * lua NvimGdb.i(0):on_tab_enter()
    au TabLeave * lua NvimGdb.i(0):on_tab_leave()
    au BufEnter * lua NvimGdb.i(0):on_buf_enter()
    au BufLeave * lua NvimGdb.i(0):on_buf_leave()
    au TabClosed * lua NvimGdb.on_tab_closed()
    au VimLeavePre * lua NvimGdb.on_vim_leave_pre()
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
