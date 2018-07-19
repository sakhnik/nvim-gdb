let s:impl = {}

function s:impl.FindSource(file)
  return ""
endfunction

function! nvimgdb#pdb#GetImpl()
  return s:impl
endfunction
