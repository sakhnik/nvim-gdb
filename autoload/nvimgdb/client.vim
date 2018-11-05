
let s:plugin_dir = expand('<sfile>:p:h:h:h')

function! nvimgdb#client#Init(proxy_cmd, client_cmd, gdb)
  " Prepare the debugger command to run
  let l:command = ''
  if a:proxy_cmd != ''
    let t:proxy_addr = tempname()
    let l:command = s:plugin_dir . '/lib/' . a:proxy_cmd . ' -a ' . t:proxy_addr . ' -- '
  endif
  let l:command .= a:client_cmd

  enew | let t:client_id = termopen(l:command, a:gdb)
  let t:client_buf = bufnr('%')
endfunction

function! nvimgdb#client#GetBuf()
  return t:client_buf
endfunction

function! nvimgdb#client#GetProxyAddr()
  return t:proxy_addr
endfunction

function! nvimgdb#client#Interrupt()
  call jobsend(t:client_id, "\<c-c>")
endfunction

function! nvimgdb#client#SendLine(data)
  call jobsend(t:client_id, a:data."\<cr>")
endfunction
