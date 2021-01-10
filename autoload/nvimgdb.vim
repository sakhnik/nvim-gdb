
let s:plugin_dir = expand('<sfile>:p:h:h')

function! nvimgdb#GetPluginDir()
  return s:plugin_dir
endfunction

function! nvimgdb#TermOpen(command, tab)
  return termopen(a:command,
    \ {'on_stdout': {j,d,e -> GdbParserFeed(a:tab, d)},
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
  command! GdbDebugStop call GdbCleanup(nvim_get_current_tabpage())
  command! GdbBreakpointToggle call GdbBreakpointToggle()
  command! GdbBreakpointClearAll call GdbBreakpointClearAll()
  command! GdbFrame call GdbSend('f')
  command! GdbRun call GdbSend('run')
  command! GdbUntil call GdbSend('until {}', line('.'))
  command! GdbContinue call GdbSend('c')
  command! GdbNext call GdbSend('n')
  command! GdbStep call GdbSend('s')
  command! GdbFinish call GdbSend('finish')
  command! GdbFrameUp call GdbSend('up')
  command! GdbFrameDown call GdbSend('down')
  command! GdbInterrupt call GdbSend()
  command! GdbEvalWord call GdbSend('print {}', expand('<cword>'))
  command! -range GdbEvalRange call GdbSend('print {}', s:GetExpression(<f-args>))
  command! -nargs=1 GdbCreateWatch call GdbCreateWatch(<q-args>)
  command! GdbCopenBacktrace call GdbCall('copen', 'backtrace')
  command! GdbCopenBreakpoints call GdbCall('copen', 'breakpoints')

  augroup NvimGdb
    au!
    au TabEnter * call GdbHandleEvent("on_tab_enter")
    au TabLeave * call GdbHandleEvent("on_tab_leave")
    au BufEnter * call GdbHandleEvent("on_buf_enter")
    au BufLeave * call GdbHandleEvent("on_buf_leave")
    au TabClosed * call GdbHandleTabClosed()
    au VimLeavePre * call GdbHandleVimLeavePre()
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
  delcommand GdbCopenBacktrace
  delcommand GdbCopenBreakpoints
endfunction
