
function! nvimgdb#TermOpen(command, tab)
  return termopen(a:command,
    \ {'on_stdout': {j,d,e -> luaeval("NvimGdb.parser_feed(_A[1], _A[2])", [a:tab, d])},
    \  'on_exit': {j,c,e -> call('nvimgdb#ExitTerm', [a:tab, c])},
    \ })
endfunction

function! nvimgdb#ExitTerm(tab, code)
  if a:code == 0
    sil! bw!
  endif
  call luaeval('NvimGdb.cleanup(_A[1])', [a:tab])
endfunction
