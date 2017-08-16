if exists("g:loaded_nvimgdb") || !has("nvim")
    finish
endif
let g:loaded_nvimgdb = 1

command! -nargs=? GdbStart call nvimgdb#Spawn(0, <q-args>, 0, 0)
nnoremap <leader>dd :GdbStart gdb -q -f a.out
