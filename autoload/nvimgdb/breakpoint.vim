sign define GdbBreakpoint text=●

let s:plugin_dir = expand('<sfile>:p:h:h:h')
let s:info_breakpoints_loaded = 0

function! s:InfoBreakpoints(file, proxy_addr)
  if !s:info_breakpoints_loaded
    exe 'luafile ' . s:plugin_dir . '/lua/info_breakpoints.lua'
    let s:info_breakpoints_loaded = 1
  endif
  return json_decode(luaeval("InfoBreakpoints(_A[1], _A[2])", [a:file, a:proxy_addr]))
endfunction

function! s:ClearBreakpointSigns()
  let i = 5000
  while i <= t:max_breakpoint_sign_id
    exe 'sign unplace '.i
    let i += 1
  endwhile
  let t:max_breakpoint_sign_id = 0
endfunction

function! s:SetBreakpointSigns(buf)
  if a:buf == -1
    return
  endif
  let t:max_breakpoint_sign_id = 5000 - 1
  for linenr in keys(get(t:breakpoints, nvimgdb#GetFullBufferPath(a:buf), {}))
    let t:max_breakpoint_sign_id += 1
    exe 'sign place '.t:max_breakpoint_sign_id.' name=GdbBreakpoint line='.linenr.' buffer='.a:buf
  endfor
endfunction

function! s:RefreshBreakpointSigns(buf)
  call s:ClearBreakpointSigns()
  call s:SetBreakpointSigns(a:buf)
endfunction

function! nvimgdb#breakpoint#Init()
  let t:breakpoints = {}
  let t:max_breakpoint_sign_id = 0
endfunction

function! nvimgdb#breakpoint#Query(bufnum, fname, proxy_addr)
  let breaks = s:InfoBreakpoints(a:fname, a:proxy_addr)
  if has_key(breaks, "_error")
    echo "Can't get breakpoints: " . breaks["_error"]
    return
  endif
  let t:breakpoints[a:fname] = breaks
  call s:RefreshBreakpointSigns(a:bufnum)
endfunction

function! nvimgdb#breakpoint#Refresh(bufnum)
  call s:RefreshBreakpointSigns(a:bufnum)
endfunction

function! nvimgdb#breakpoint#Clear()
  call s:ClearBreakpointSigns()
endfunction

function! nvimgdb#breakpoint#Cleanup()
  let t:breakpoints = {}
  call s:ClearBreakpointSigns()
endfunction

function! nvimgdb#breakpoint#GetForFile(fname)
  return get(t:breakpoints, a:fname, {})
endfunction
