cur_tab = vim.api.nvim_get_current_tabpage

V = {
    cur_tab: cur_tab,
    set_tvar: (k,v) -> vim.api.nvim_tabpage_set_var(cur_tab!, k, v),
    get_tvar: (k) -> vim.api.nvim_tabpage_get_var(cur_tab!, k),
    cmd: (c) -> vim.api.nvim_command(c),
    call: (n, a) -> vim.api.nvim_call_function(n, a),
}

V.def_tvar = (n) -> {
    set: (v) -> V.set_tvar(n, v),
    get: () -> V.get_tvar(n),
}

V
