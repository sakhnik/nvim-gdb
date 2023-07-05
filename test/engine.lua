local thr = require'thread'
local E = {}

function E.feed(keys)
  vim.api.nvim_input(keys)
  thr.y(200)
end

function E.get_time_ms()
  return vim.loop.hrtime() * 1e-6
end

function E.wait_paused(timeout_ms)
  if timeout_ms == nil then
    timeout_ms = 5000
  end
  local deadline = E.get_time_ms() + timeout_ms
  while E.get_time_ms() < deadline do
    if NvimGdb ~= nil and NvimGdb.i().parser:is_paused() then
      return true
    end
    thr.y(100)
  end
  return false
end

function E.count_buffers()
  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      count = count + 1
    end
  end
  return count
end

return E
