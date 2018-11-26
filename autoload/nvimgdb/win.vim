
function! nvimgdb#win#Init()
  " window number that will be displaying the current file
  let t:gdb_win_jump_window = 1
  let t:gdb_win_current_buf = -1
endfunction

function! nvimgdb#win#Cleanup()
  call nvimgdb#breakpoint#Disconnect(nvimgdb#client#GetProxyAddr())
endfunction

function! nvimgdb#win#GetCurrentBuffer()
  return t:gdb_win_current_buf
endfunction

function! nvimgdb#win#Jump(file, line)
  let window = winnr()
  exe t:gdb_win_jump_window 'wincmd w'
  let t:gdb_win_current_buf = bufnr('%')
  let target_buf = bufnr(a:file, 1)
  if target_buf == nvimgdb#client#GetBuf()
    " The terminal buffer may contain the name of the source file (in pdb, for
    " instance)
    exe "noswapfile view " . a:file
    let target_buf = bufnr(a:file)
  endif

  if bufnr('%') != target_buf
    " Switch to the new buffer
    exe 'noswapfile buffer ' target_buf
    let t:gdb_win_current_buf = target_buf
    call nvimgdb#breakpoint#Refresh(t:gdb_win_current_buf)
  endif

  exe ':' a:line
  call nvimgdb#cursor#Set(a:line)
  exe window 'wincmd w'
  call nvimgdb#cursor#Show()
endfunction

function! nvimgdb#win#QueryBreakpoints()
  " Get the source code buffer number
  if bufnr('%') == nvimgdb#client#GetBuf()
    " The debugger terminal window is currently focused, so perform a couple
    " of jumps.
    let window = winnr()
    exe t:gdb_win_jump_window 'wincmd w'
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
  call nvimgdb#breakpoint#Query(bufnum, fname, nvimgdb#client#GetProxyAddr())

  " Redraw the cursor over breakpoint if was set before.
  call nvimgdb#cursor#Reshow()
endfunction
