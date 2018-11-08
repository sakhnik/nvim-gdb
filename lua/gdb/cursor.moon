get_tab = vim.api.nvim_get_current_tabpage

V = {
    set_tvar: (k,v) -> vim.api.nvim_tabpage_set_var(get_tab!, k, v),
    get_tvar: (k) -> vim.api.nvim_tabpage_get_var(get_tab!, k),
    command: (c) -> vim.api.nvim_command(c),
    call: (n, a) -> vim.api.nvim_call_function(n, a),
}

def_tvar = (n) -> {
    set: (v) -> V.set_tvar(n, v),
    get: () -> V.get_tvar(n),
}

line = def_tvar("gdb_cursor_line")
sign_id = def_tvar("gdb_cursor_sign_id")

CursorInit = ->
    line.set(-1)
    sign_id.set(4999)

CursorDisplay = (add) ->
    -- to avoid flicker when removing/adding the sign column(due to the change in
    -- line width), we switch ids for the line sign and only remove the old line
    -- sign after marking the new one
    old_sign_id = sign_id.get()
    sign_id.set((old_sign_id == 4999) and 4998 or 4999)
    current_buf = V.call("nvimgdb#win#GetCurrentBuffer", {})
    if add != 0 and line.get() != -1 and current_buf != -1
        V.command('sign place ' .. sign_id.get() .. ' name=GdbCurrentLine line=' ..
            line.get() .. ' buffer=' .. current_buf)
    endif
    V.command('sign unplace ' .. old_sign_id)

ret = {
    init: CursorInit,
    set: line.set,
    display: CursorDisplay,
}
ret
