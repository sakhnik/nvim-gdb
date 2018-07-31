let s:root_dir = expand('<sfile>:p:h:h:h')
let s:impl = {}


function! nvimgdb#gdb#GetImpl()
    return s:impl
endfunction
