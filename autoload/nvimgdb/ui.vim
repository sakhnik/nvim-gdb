
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
  delcommand GdbInterrupt
  delcommand GdbEvalWord
  delcommand GdbEvalRange
endfunction

function! s:DefineCommands()
  command! GdbDebugStop call nvimgdb#Kill()
  command! GdbBreakpointToggle lua gdb.app.dispatch("toggleBreak")
  command! GdbBreakpointClearAll lua gdb.app.dispatch("clearBreaks")
  command! GdbRun lua gdb.app.dispatch('send', 'run')
  command! GdbUntil call luaeval("gdb.app.dispatch('send', gdb.app.dispatch('getCommand', 'until') .. ' ' .. _A)", line('.'))
  command! GdbContinue lua gdb.app.dispatch('send', 'c')
  command! GdbNext lua gdb.app.dispatch('send', 'n')
  command! GdbStep lua gdb.app.dispatch('send', 's')
  command! GdbFinish lua gdb.app.dispatch('send', 'finish')
  command! GdbFrameUp lua gdb.app.dispatch('send', 'up')
  command! GdbFrameDown lua gdb.app.dispatch('send', 'down')
  command! GdbInterrupt lua gdb.app.dispatch('interrupt')
  command! GdbEvalWord call luaeval("gdb.app.dispatch('send', _A)", 'print ' . expand('<cword>'))
  command! -range GdbEvalRange call luaeval("gdb.app.dispatch('send', _A)", 'print ' . s:GetExpression(<f-args>))
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
      " Unfortunately, there is no event to handle a window closed.
      " It's needed to be handled heuristically:
      "   When :quit is executed, the cursor will enter another buffer
      au WinEnter * call nvimgdb#CheckWindowClosed()
      "   When :only is executed, BufWinLeave will be issued before closing
      "   window. We start a timer expecting it to expire after the window
      "   has been closed. It's a race.
      au BufWinLeave * call timer_start(100, "nvimgdb#CheckWindowClosed")
      au TabEnter * lua gdb.app.dispatch("tabEnter")
      au TabLeave * lua gdb.app.dispatch("tabLeave")
      au BufEnter * call nvimgdb#OnBufEnter()
      au BufLeave * call nvimgdb#OnBufLeave()
    augroup END
  endif
  let g:nvimgdb_count += 1
endfunction
