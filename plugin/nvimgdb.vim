if exists("g:loaded_nvimgdb") || !has("nvim")
    finish
endif
let g:loaded_nvimgdb = 1

command! -nargs=1 -complete=shellcmd GdbStart call nvimgdb#Spawn('gdb', 'gdb_wrap.sh', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartLLDB call nvimgdb#Spawn('lldb', 'lldb_wrap.sh', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartPDB call nvimgdb#Spawn('pdb', 'pdb_proxy.py', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartBashDB call nvimgdb#Spawn('bashdb', 'bashdb_proxy.py', <q-args>)

if !exists('g:nvimgdb_disable_start_keymaps') || !g:nvimgdb_disable_start_keymaps
  nnoremap <leader>dd :GdbStart gdb -q a.out
  nnoremap <leader>dl :GdbStartLLDB lldb a.out
  nnoremap <leader>dp :GdbStartPDB python -m pdb main.py
  nnoremap <leader>db :GdbStartBashDB bashdb main.sh
endif
