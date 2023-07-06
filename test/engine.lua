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

function E.count_buffers_impl(pred)
  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if pred(buf) then
      count = count + 1
    end
  end
  return count
end

function E.count_buffers()
  -- Determine how many terminal buffers are there.
  return E.count_buffers_impl(function(buf)
    return vim.api.nvim_buf_is_loaded(buf)
  end)
end

function E.count_termbuffers()
  -- Determine how many terminal buffers are there.
  return E.count_buffers_impl(function(buf)
    return vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, 'buftype') == 'terminal'
  end)
end

function E.get_signs()
  -- Get pointer position and list of breakpoints.
  local ret = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local breaks = {}
      for _, bsigns in ipairs(vim.fn.sign_getplaced(buf, {group = "NvimGdb"})) do
        for _, signs in ipairs(bsigns.signs) do
          local sname = signs.name
          if sname == 'GdbCurrentLine' then
            local bname = vim.api.nvim_buf_get_name(buf):match("[^/\\]+$")
            if ret.cur == nil then
              ret.cur = bname .. ':' .. signs.lnum
            else
              if ret.curs == nil then
                ret.curs = {}
              end
              table.insert(ret.curs, bname .. ':' .. signs.lnum)
            end
          end
          if sname:match('^GdbBreakpoint') then
            local num = assert(tonumber(sname:sub(string.len('GdbBreakpoint'))))
            if breaks[num] == nil then
              breaks[num] = {}
            end
            table.insert(breaks[num], signs.lnum)
          end
        end
      end
      if #breaks > 0 then
        ret.brk = breaks
      end
    end
  end
  return ret
end

return E
