
" Count of active debugging views
let g:nvimgdb_count = 0


function! s:GetExpression(...) range
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][:col2 - 1]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, "\n")
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
  delcommand GdbFrame
  delcommand GdbInterrupt
  delcommand GdbEvalWord
  delcommand GdbEvalRange
endfunction

function! s:DefineCommands()
  command! GdbDebugStop call nvimgdb#Kill()
  command! GdbBreakpointToggle call GdbBreakpointToggle()
  command! GdbBreakpointClearAll call GdbBreakpointClearAll()
  command! GdbRun call GdbSend('run')
  command! GdbUntil call GdbSend('until {}', line('.'))
  command! GdbContinue call GdbSend('c')
  command! GdbNext call GdbSend('n')
  command! GdbStep call GdbSend('s')
  command! GdbFinish call GdbSend('finish')
  command! GdbFrameUp call GdbSend('up')
  command! GdbFrame call GdbSend('frame')
  command! GdbFrameDown call GdbSend('down')
  command! GdbInterrupt call GdbSend()
  command! GdbEvalWord call GdbSend('print {}', expand('<cword>'))
  command! -range GdbEvalRange call GdbSend('print {}', s:GetExpression(<f-args>))
endfunction


function! nvimgdb#ui#Leave()
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
endfunction

function! nvimgdb#ui#Enter()
  if !g:nvimgdb_count
    call s:DefineCommands()
    augroup NvimGdb
      au!
      "   When :only is executed, BufWinLeave will be issued before closing
      "   window. We start a timer expecting it to expire after the window
      "   has been closed. It's a race.
      au TabEnter * call GdbHandleEvent("on_tab_enter")
      au TabLeave * call GdbHandleEvent("on_tab_leave")
      au BufEnter * call GdbHandleEvent("on_buf_enter")
      au BufLeave * call GdbHandleEvent("on_buf_leave")
    augroup END
  endif
  let g:nvimgdb_count += 1
endfunction
