let s:root_dir = expand('<sfile>:p:h:h:h')
let s:impl = {}


function s:DoFindSource(file)
  exe 'py3 import sys'
  exe 'py3 sys.argv = ["' . a:file . '"]'
  exe 'py3file ' . s:root_dir . '/lib/gdb_find_source.py'
  return return_value
endfunction

function s:impl.FindSource(file)
  if filereadable(a:file)
    return fnamemodify(a:file, ':p')
  endif

  let ret = s:DoFindSource(a:file)
  if !len(ret)
    return ""
  elseif len(ret) == 1
    return ret[0]
  else
    " TODO: inputlist()
    return ""
  endif
endfunction


function s:impl.InfoBreakpoints(file)
  exe 'py3 import sys'
  exe 'py3 sys.argv = ["' . a:file . '"]'
  exe 'py3file ' . s:root_dir . '/lib/gdb_info_breakpoints.py'
  return json_decode(return_value)
endfunction


function! nvimgdb#gdb#GetImpl()
    return s:impl
endfunction
