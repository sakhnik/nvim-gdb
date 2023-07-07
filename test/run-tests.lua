local uv = vim.loop

local server = uv.new_tcp()
server:bind("127.0.0.1", 11111)
server:listen(5, function(err)
  assert(not err, err)
  local sock = vim.loop.new_tcp()
  sock:nodelay(true)
  server:accept(sock)
  sock:read_start(function(err2, chunk)
    assert(not err2, err2) -- Check for errors.
    if chunk then
      io.stdout:write(chunk)
      io.stdout:flush()
    else
      sock:close()
    end
  end)
end)


local opts = {
  on_stdout = function(_, d, _)
    --io.stdout:write(vim.inspect({d}))
  end,
  on_stderr = function(_, d, _)
    --io.stderr:write(vim.inspect({d}))
  end,
  on_exit = function(_, c, _)
    os.exit(c)
  end
}

local job_id = assert(vim.fn.jobstart({"python", "nvim.py", "--headless", "+luafile config_ci.lua", "+luafile main.lua"}, opts))

local signal = uv.new_signal()
vim.loop.signal_start(signal, "sigint", vim.schedule_wrap(function(_)
  vim.fn.jobstop(job_id)
  os.exit(1)
end))

vim.wait(30 * 60 * 1000, function() return false end)
