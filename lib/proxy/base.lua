local uv = vim.loop

-- Get rid of the script, leave the arguments only
arg[0] = nil

local opts = {
  pty = true,
  env = {
    TERM = vim.env.TERM
  },

  on_stdout = function(_, d, _)
    local nl = ''
    for i, chunk in ipairs(d) do
      if chunk ~= '' or i ~= 1 then
        io.stdout:write(nl, chunk)
      end
      nl = '\n'
    end
  end,

  on_exit = function(_, c, _)
    os.exit(c)
  end
}

local job_id = assert(vim.fn.jobstart({"python", "-m", "pdb", "test/main.py"}, opts))

do  -- Set terminal raw mode
  local stdin = uv.new_tty(0, true)            -- 0 represents stdin file descriptor
  local result, error_msg = stdin:set_mode(1)  -- uv.TTY_MODE_RAW
  assert(result, error_msg)
end

do  -- Read stdin and pass to the slave
  local stdin = uv.new_pipe(false)
  uv.pipe_open(stdin, 0)  -- 0 represents stdin file descriptor

  -- Read data from stdin
  stdin:read_start(vim.schedule_wrap(function(err, chunk)
    assert(not err, err)

    if chunk then
      vim.fn.chansend(job_id, chunk)
    else
      -- End of input, process the data
      stdin:close()
    end
  end))
end

vim.wait(10^9, function() return false end)
