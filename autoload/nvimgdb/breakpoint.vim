sign define GdbBreakpoint text=●

let s:plugin_dir = expand('<sfile>:p:h:h:h')
let s:info_breakpoints_loaded = 0

function! s:InfoBreakpoints(file, proxy_addr)
  if !s:info_breakpoints_loaded
    exe 'py3file ' . s:plugin_dir . '/lib/info_breakpoints.py'
    let s:info_breakpoints_loaded = 1
  endif
  return json_decode(py3eval("InfoBreakpoints('" . a:file . "', '" . a:proxy_addr . "')"))
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
  if s:info_breakpoints_loaded
    call py3eval("InfoBreakpointsDisconnect('" . a:proxy_addr . "')")
  endif
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
