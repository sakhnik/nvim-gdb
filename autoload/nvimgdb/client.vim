
let s:plugin_dir = expand('<sfile>:p:h:h:h')

function! nvimgdb#client#Init(proxy_cmd, client_cmd, gdb)
  " Prepare the debugger command to run
  let l:command = ''
  if a:proxy_cmd != ''
    let t:gdb_client_proxy_addr = tempname()
    let l:command = s:plugin_dir . '/lib/' . a:proxy_cmd . ' -a ' . t:gdb_client_proxy_addr . ' -- '
  endif
  let l:command .= a:client_cmd

  enew | let t:gdb_client_id = termopen(l:command, a:gdb)
  let t:gdb_client_buf = bufnr('%')
endfunction

function! nvimgdb#client#GetBuf()
  return t:gdb_client_buf
endfunction

function! nvimgdb#client#GetProxyAddr()
  return t:gdb_client_proxy_addr
endfunction

function! nvimgdb#client#Interrupt()
  call jobsend(t:gdb_client_id, "\<c-c>")
endfunction

function! nvimgdb#client#SendLine(data)
  call jobsend(t:gdb_client_id, a:data."\<cr>")
endfunction
