if exists("g:loaded_nvimgdb") || !has("nvim")
    finish
endif
let g:loaded_nvimgdb = 1

command! -nargs=1 -complete=shellcmd GdbStart call nvimgdb#Spawn('gdb', 'gdbproxy.py', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartLLDB call nvimgdb#Spawn('lldb', '', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartPDB call nvimgdb#Spawn('pdb', '', <q-args>)

if !exists('g:nvimgdb_disable_start_keymaps') || !g:nvimgdb_disable_start_keymaps
  nnoremap <leader>dd :GdbStart gdb -q -f a.out
  nnoremap <leader>dl :GdbStartLLDB lldb a.out
  nnoremap <leader>dp :GdbStartPDB python -m pdb main.py
endif
