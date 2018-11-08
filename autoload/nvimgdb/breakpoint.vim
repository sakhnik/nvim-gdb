sign define GdbBreakpoint text=●

function! s:InfoBreakpoints(file, proxy_addr)
  return json_decode(luaeval("gdb.breakpoint.query(_A[1], _A[2])", [a:file, a:proxy_addr]))
endfunction

function! s:ClearBreakpointSigns()
  let i = 5000
  while i <= t:gdb_breakpoint_max_sign_id
    exe 'sign unplace '.i
    let i += 1
  endwhile
  let t:gdb_breakpoint_max_sign_id = 0
endfunction

function! s:SetBreakpointSigns(buf)
  if a:buf == -1
    return
  endif
  let t:gdb_breakpoint_max_sign_id = 5000 - 1
  for linenr in keys(get(t:gdb_breakpoints, nvimgdb#GetFullBufferPath(a:buf), {}))
    let t:gdb_breakpoint_max_sign_id += 1
    exe 'sign place '.t:gdb_breakpoint_max_sign_id.' name=GdbBreakpoint line='.linenr.' buffer='.a:buf
  endfor
endfunction

function! s:RefreshBreakpointSigns(buf)
  call s:ClearBreakpointSigns()
  call s:SetBreakpointSigns(a:buf)
endfunction

function! nvimgdb#breakpoint#Init()
  let t:gdb_breakpoints = {}
  let t:gdb_breakpoint_max_sign_id = 0
endfunction

function! nvimgdb#breakpoint#Disconnect(proxy_addr)
  call luaeval("gdb.breakpoint.disconnect(_A)", a:proxy_addr)
endfunction

function! nvimgdb#breakpoint#Query(bufnum, fname, proxy_addr)
  let breaks = s:InfoBreakpoints(a:fname, a:proxy_addr)
  if has_key(breaks, "_error")
    echo "Can't get breakpoints: " . breaks["_error"]
    return
  endif
  let t:gdb_breakpoints[a:fname] = breaks
  call s:RefreshBreakpointSigns(a:bufnum)
endfunction

function! nvimgdb#breakpoint#Refresh(bufnum)
  call s:RefreshBreakpointSigns(a:bufnum)
endfunction

function! nvimgdb#breakpoint#Clear()
  call s:ClearBreakpointSigns()
endfunction

function! nvimgdb#breakpoint#Cleanup()
  let t:gdb_breakpoints = {}
  call s:ClearBreakpointSigns()
endfunction

function! nvimgdb#breakpoint#GetForFile(fname)
  return get(t:gdb_breakpoints, a:fname, {})
endfunction
