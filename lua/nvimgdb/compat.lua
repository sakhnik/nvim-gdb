local C = {}

C.g = setmetatable({}, {
  __index = function(_, key)
    if 0 == vim.api.nvim_eval("exists('g:" .. key .. "')") then
      return nil
    end
    return vim.api.nvim_get_var(key)
  end,
  __newindex = function(_, key, val)
    vim.api.nvim_set_var(key, val)
  end,
})

C.b = setmetatable({}, {
  __index = function(_, key)
    if 0 == vim.api.nvim_eval("exists('b:" .. key .. "')") then
      return nil
    end
    return vim.api.nvim_buf_get_var(vim.api.nvim_get_current_buf(), key)
  end,
  __newindex = function(_, key, val)
    vim.api.nvim_buf_set_var(vim.api.nvim_get_current_buf(), key, val)
  end,
})

C.w = setmetatable({}, {
  __index = function(_, key)
    if 1 ~= vim.api.nvim_eval("exists('w:" .. key .. "')") then
      return nil
    end
    return vim.api.nvim_win_get_var(vim.api.nvim_get_current_win(), key)
  end,
  __newindex = function(_, key, val)
    vim.api.nvim_win_set_var(vim.api.nvim_get_current_win(), key, val)
  end,
})

C.t = setmetatable({}, {
  __index = function(_, key)
    if 0 == vim.api.nvim_eval("exists('t:" .. key .. "')") then
      return nil
    end
    return vim.api.nvim_tabpage_get_var(vim.api.nvim_get_current_tabpage(), key)
  end,
  __newindex = function(_, key, val)
    vim.api.nvim_tabpage_set_var(vim.api.nvim_get_current_tabpage(), key, val)
  end,
})

C.fn = setmetatable({}, {
  __index = function(_, key)
    return function(...)
      return vim.api.nvim_call_function(key, {...})
    end
  end,
})

C.cmd = vim.api.nvim_command

C.o = setmetatable({}, {
  __index = function(_, key)
    return vim.api.nvim_get_option(key)
  end,
  __newindex = function(_, key, val)
    vim.api.nvim_set_option(key, val)
  end,
})

C.bo = setmetatable({}, {
  __index = function(_, key)
    return vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), key)
  end,
  __newindex = function(_, key, val)
    vim.api.nvim_buf_set_option(vim.api.nvim_get_current_buf(), key, val)
  end,
})

C.wo = setmetatable({}, {
  __index = function(_, key)
    return vim.api.nvim_win_get_option(vim.api.nvim_get_current_win(), key)
  end,
  __newindex = function(_, key, val)
    vim.api.nvim_win_set_option(vim.api.nvim_get_current_win(), key, val)
  end,
})

return C
