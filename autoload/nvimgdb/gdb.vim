let s:root_dir = expand('<sfile>:p:h:h:h')
let s:impl = {}


function s:impl.InfoBreakpoints(file)
  exe 'py3 import sys'
  exe 'py3 sys.argv = ["' . a:file . '"]'
  exe 'py3file ' . s:root_dir . '/lib/gdb_info_breakpoints.py'
  return json_decode(return_value)
endfunction


function! nvimgdb#gdb#GetImpl()
    return s:impl
endfunction
