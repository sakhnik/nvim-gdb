if exists("g:loaded_nvimgdb") || !has("nvim")
    finish
endif
let g:loaded_nvimgdb = 1

command! -nargs=1 -complete=shellcmd GdbStart call nvimgdb#Spawn('gdb', <q-args>)
command! -nargs=1 -complete=shellcmd GdbStartLLDB call nvimgdb#Spawn('lldb', <q-args>)
nnoremap <leader>dd :GdbStart gdb -q -f a.out
nnoremap <leader>dl :GdbStartLLDB lldb a.out
