
sign define GdbCurrentLine text=⇒

function! nvimgdb#cursor#Init()
  let t:gdb_cursor_line = -1
  let t:gdb_cursor_sign_id = -1
endfunction

function! nvimgdb#cursor#Hide()
  if t:gdb_cursor_sign_id != -1
    exe 'sign unplace '.t:gdb_cursor_sign_id
    let t:gdb_cursor_sign_id = -1
  endif
endfunction

function! nvimgdb#cursor#Show()
  " to avoid flicker when removing/adding the sign column(due to the change in
  " line width), we switch ids for the line sign and only remove the old line
  " sign after marking the new one
  let old_line_sign_id = t:gdb_cursor_sign_id
  let t:gdb_cursor_sign_id = 4999 + (old_line_sign_id != -1 ? 4998 - old_line_sign_id : 0)
  let current_buf = nvimgdb#win#GetCurrentBuffer()
  if t:gdb_cursor_line != -1 && current_buf != -1
    exe 'sign place '.t:gdb_cursor_sign_id.' name=GdbCurrentLine line='
          \.t:gdb_cursor_line.' buffer='.current_buf
  endif
  if old_line_sign_id != -1
    exe 'sign unplace '.old_line_sign_id
  endif
endfunction

function! nvimgdb#cursor#Set(line)
  let t:gdb_cursor_line = a:line
endfunction

function! nvimgdb#cursor#Reshow()
  if t:gdb_cursor_sign_id != -1
    call nvimgdb#cursor#Show()
  endif
endfunction
