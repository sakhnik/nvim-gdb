if exists("g:loaded_nvimgdb") || !has("nvim")
    finish
endif
let g:loaded_nvimgdb = 1

function! s:Spawn(backend, proxy_cmd, client_cmd)
  "Expand words in the client_cmd to support %, <word> etc
  let cmd = join(map(split(a:client_cmd), {k, v -> expand(v)}))
  call luaeval("require'nvimgdb'.new(_A[1], _A[2], _A[3])", [a:backend, a:proxy_cmd, cmd])
endfunction

command! -nargs=1 -complete=customlist,ExecsCompletion GdbStart call s:Spawn('gdb', 'launch_gdb.py', <q-args>)
command! -nargs=1 -complete=customlist,ExecsCompletion GdbStartLLDB call s:Spawn('lldb', 'launch_lldb.py', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartPDB call s:Spawn('pdb', 'launch_pdb.py', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartBashDB call s:Spawn('bashdb', 'launch_bashdb.py', <q-args>)
command! GdbStartRR call s:Spawn('gdb', 'launch_gdb.py', 'rr-replay.py')

function IsExec(exec)
  eval system('test -x ' . a:exec)
  return v:shell_error==0
endfunction

if !exists("g:nvimgdb_use_find_executables")
  let g:nvimgdb_use_find_executables=1
endif
if !exists("g:nvimgdb_use_cmake_to_find_executables")
  let g:nvimgdb_use_cmake_to_find_executables=1
endif

function ExecsCompletion(ArgLead, CmdLine, CursorPos)
  " Use `find`
  let find_cmd="find " . a:ArgLead . '* -type f -not -path "**/CMakeFiles/**"'
  echom "find_cmd: '" . find_cmd . "'"
  let found_executables = g:nvimgdb_use_find_executables ? 
        \systemlist(find_cmd) : []
  if v:shell_error
    let found_executables = []
  endif
  call filter(found_executables, {idx, exec -> IsExec(exec)})
  echom "found_executables: " . join(found_executables, ', ')
  call filter(found_executables, {idx, exec -> match(systemlist('file --brief --mime-encoding ' . exec)[0], 'binary')>=0})
  call map(found_executables, {idx, exec -> substitute(exec, '/\{2,}', '/', 'g')})
  echom "after filter: found_executables: " . join(found_executables, ', ')

  " Use CMake
  let cmake_executables = g:nvimgdb_use_cmake_to_find_executables ? 
        \guess_executable_cmake#ExecutablesOfBuffer(a:ArgLead) : []
  echom "Cmake Execs: "  cmake_executables
  return extend(cmake_executables, found_executables)
endfunction

if !exists('g:nvimgdb_disable_start_keymaps') || !g:nvimgdb_disable_start_keymaps
  nnoremap <leader>dd :GdbStart gdb -q 
  nnoremap <leader>dl :GdbStartLLDB lldb
  nnoremap <leader>dp :GdbStartPDB python -m pdb main.py
  nnoremap <leader>db :GdbStartBashDB bashdb main.sh
  nnoremap <leader>dr :GdbStartRR
endif
