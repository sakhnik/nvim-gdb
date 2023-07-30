local uv = vim.loop

-- Get rid of the script, leave the arguments only
arg[0] = nil

local server = uv.new_tcp()
server:bind("127.0.0.1", 11111)
server:listen(5, function(err)
  assert(not err, err)
  local sock = vim.loop.new_tcp()
  sock:nodelay(true)
  server:accept(sock)
  sock:read_start(function(err2, chunk)
    if err2 == "ECONNRESET" then
      sock:close()
      return
    end
    assert(not err2, err2) -- Check for errors.
    if chunk then
      io.stdout:write(chunk)
      io.stdout:flush()
    else
      sock:close()
    end
  end)
end)

local function assemble_output(_, d, _)
  -- :help channel-lines: the first and the last chunk of the data
  -- may belong to the same line
  local nl = ''
  for i, chunk in ipairs(d) do
    if i == 1 and chunk == '' then
      nl = '\n'
    end
    io.stdout:write(nl, chunk)
    nl = '\n'
  end
end

local opts = {
  on_stdout = assemble_output,
  on_stderr = assemble_output,
  on_exit = function(_, c, _)
    os.exit(c)
  end
}

local job_nvim = assert(
  vim.fn.jobstart({
      "python", "nvim.py", "--embed", "--headless", "-n",
      "+let g:busted_arg=json_decode('" .. vim.fn.json_encode(arg) .. "')",
      "+luafile config_ci.lua",
      "+luafile main.lua"
  }, opts))

local signal = uv.new_signal()
vim.loop.signal_start(signal, "sigint", vim.schedule_wrap(function(_)
  vim.fn.jobstop(job_nvim)
  os.exit(1)
end))

--local channel = nil;
--assert(vim.wait(1000, function()
--  local ok, ch = pcall(vim.fn.sockconnect, 'tcp', 'localhost:44444', {rpc = true})
--  channel = ch
--  return ok
--end))
--
--vim.fn.rpcrequest(channel, "nvim_ui_attach", 80, 25, {ext_linegrid = true})

vim.wait(30 * 60 * 1000, function() return false end)
