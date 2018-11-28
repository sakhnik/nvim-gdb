V = {}

-- Simplify access to the neovim API: "vim.api.nvim_<key>" -> "<key>"
for k, v in pairs(vim.api)
    if string.sub(k, 1, 5) == 'nvim_'
        V[string.sub(k, 6)] = v
    else
        V[k] = v

V.win_get_nr = V.win_get_number
V.cur_winnr = -> V.win_get_number(V.get_current_win!)
V.cur_buf = V.get_current_buf
V.get_buf_option = V.buf_get_option
V.exe = (c) -> V.command c
V.call = (n, a) -> V.call_function(n, a)

-- Check whether buf is loaded.
-- The API function is available since API level 5
if V.buf_is_loaded == nil
    -- Fall back to the Vim function
    V.buf_is_loaded = (b) -> V.call("bufexists", {b}) != 0

-- Jump to the given window number
V.jump_win = (num) ->
    V.exe (num .. 'wincmd w')

V
