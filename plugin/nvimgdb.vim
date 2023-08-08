if 1 != has("nvim-0.9.0")
  nvim_err_writeln("nvimgdb requires at least nvim-0.9.0")
  finish
endif

if exists("g:loaded_nvimgdb") || !has("nvim")
  finish
endif
let g:loaded_nvimgdb = 1

lua require'nvimgdb'.setup()
