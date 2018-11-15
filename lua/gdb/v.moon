cur_tab = vim.api.nvim_get_current_tabpage

V = {
    cur_tab: cur_tab
    cur_win: vim.api.nvim_get_current_win
    list_wins: -> vim.api.nvim_tabpage_list_wins(cur_tab!)
    list_tabs: vim.api.nvim_list_tabpages
    win_get_nr: vim.api.nvim_win_get_number
    win_get_buf: vim.api.nvim_win_get_buf
    cur_winnr: -> vim.api.nvim_win_get_number(vim.api.nvim_get_current_win!)
    cur_buf: vim.api.nvim_get_current_buf
    set_tvar: (k,v) -> vim.api.nvim_tabpage_set_var(cur_tab!, k, v)
    get_tvar: (k) -> vim.api.nvim_tabpage_get_var(cur_tab!, k)
    exe: (c) -> vim.api.nvim_command(c)
    call: (n, a) -> vim.api.nvim_call_function(n, a)
}

-- Check whether buf is loaded.
-- The API function is available since API level 5
V.buf_is_loaded = vim.api.nvim_buf_is_loaded
if V.buf_is_loaded == nil
    -- Fall back to the Vim function
    V.buf_is_loaded = (b) -> V.call("bufexists", {b}) != 0

V
