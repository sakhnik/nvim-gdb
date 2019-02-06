V = {}

-- Simplify access to the neovim API: "vim.api.nvim_<key>" -> "<key>"
for k, v in pairs(vim.api)
    if string.sub(k, 1, 5) == 'nvim_'
        V[string.sub(k, 6)] = v
    else
        V[k] = v

-- Aliases for vim-like commands :exe and :call
V.exe = V.command
V.call = V.call_function

-- Check whether buf is loaded.
-- The API function is available since API level 5
if V.buf_is_loaded == nil
    -- Fall back to the Vim function
    V.buf_is_loaded = (b) -> V.call("bufexists", {b}) != 0

-- Jump to the given window number
V.jump_win = (win) ->
    V.exe (V.win_get_number(win) .. 'wincmd w')

V
