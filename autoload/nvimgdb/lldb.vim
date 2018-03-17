let s:impl = {}

function s:impl.FindSource(file)
  return ""
endfunction

function! nvimgdb#lldb#GetImpl()
  return s:impl
endfunction
