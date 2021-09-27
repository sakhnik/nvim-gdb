if exists("g:loaded_nvimgdb") || !has("nvim")
    finish
endif
let g:loaded_nvimgdb = 1

function! s:Spawn(backend, proxy_cmd, client_cmd)
  "Expand words in the client_cmd to support %, <word> etc
  let cmd = join(map(split(a:client_cmd), {k, v -> expand(v)}))
  call luaeval("require'nvimgdb'.new(_A[1], _A[2], _A[3])", [a:backend, a:proxy_cmd, cmd])
endfunction

command! -nargs=1 -complete=customlist,ExecsCompletion GdbStart call s:Spawn('gdb', 'gdb_wrap.sh', <q-args>)
command! -nargs=1 -complete=customlist,ExecsCompletion GdbStartLLDB call s:Spawn('lldb', 'lldb_wrap.sh', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartPDB call s:Spawn('pdb', 'pdb_proxy.py', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartBashDB call s:Spawn('bashdb', 'bashdb_proxy.py', <q-args>)

let g:use_find_executables=1
let g:find_executables_base_dir='.'
let g:use_cmake_to_find_executables=1
function ExecsCompletion(ArgLead, CmdLine, CursorPos)
  " Use `find`
  let find_cmd="find " . a:ArgLead . '* -type f -executable -not -path "**/CMakeFiles/**"'
  echom "find_cmd: '" . find_cmd . "'"
  let found_executables = g:use_find_executables ? 
        \systemlist(find_cmd) : []
  if v:shell_error
    let found_executables = []
  endif
  echom "found_executables: " . join(found_executables, ', ')

  " Use CMake
  let cmake_executables = g:use_cmake_to_find_executables ? 
        \guess_executable_cmake#ExecutablesOfBuffer(a:ArgLead) : []
  return extend(cmake_executables, found_executables)
endfunction

if !exists('g:nvimgdb_disable_start_keymaps') || !g:nvimgdb_disable_start_keymaps
  nnoremap <leader>dd :GdbStart gdb -q 
  nnoremap <leader>dl :GdbStartLLDB lldb a.out
  nnoremap <leader>dp :GdbStartPDB python -m pdb main.py
  nnoremap <leader>db :GdbStartBashDB bashdb main.sh
endif
