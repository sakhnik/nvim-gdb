
function! nvimgdb#TermOpen(command, tab)
  return termopen(a:command,
    \ {'on_stdout': {j,d,e -> luaeval("NvimGdb.parser_feed(_A[1], _A[2])", [a:tab, d])},
    \  'on_exit': {j,c,e -> call('nvimgdb#ExitTerm', [a:tab, c])},
    \ })
endfunction

function! nvimgdb#ExitTerm(tab, code)
  if a:code == 0
    sil! bw!
  endif
  call luaeval('NvimGdb.cleanup(_A[1])', [a:tab])
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
  delcommand Gdb
  delcommand GdbLopenBacktrace
  delcommand GdbLopenBreakpoints
endfunction
