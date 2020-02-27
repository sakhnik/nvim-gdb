if exists("g:loaded_nvimgdb") || !has("nvim")
    finish
endif
let g:loaded_nvimgdb = 1

function! s:Spawn(backend, proxy_cmd, client_cmd)
  "Expand words in the client_cmd to support %, <word> etc
  let cmd = join(map(split(a:client_cmd), {k, v -> expand(v)}))
  call GdbInit(a:backend, a:proxy_cmd, cmd)
endfunction

command! -nargs=1 -complete=shellcmd GdbStart call s:Spawn('gdb', 'gdb_wrap.sh', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartLLDB call s:Spawn('lldb', 'lldb_wrap.sh', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartPDB call s:Spawn('pdb', 'pdb_proxy.py', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartBashDB call s:Spawn('bashdb', 'bashdb_proxy.py', <q-args>)

if !exists('g:nvimgdb_disable_start_keymaps') || !g:nvimgdb_disable_start_keymaps
  nnoremap <leader>dd :GdbStart gdb -q a.out
  nnoremap <leader>dl :GdbStartLLDB lldb a.out
  nnoremap <leader>dp :GdbStartPDB python -m pdb main.py
  nnoremap <leader>db :GdbStartBashDB bashdb main.sh
endif
