" Undefine all global variables prefixed nvimgdb_
silent call execute('redir => vars | let g: | redir END')

for line in split(vars, "\n")
  let name = split(line)[0]
  if -1 != match(name, '^nvimgdb_.*$') && name != 'nvimgdb_count'
    exe "unlet! " . name
  endif
endfor

unlet vars
