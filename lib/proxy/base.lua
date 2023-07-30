local uv = vim.loop

local Proxy = { }
Proxy.__index = Proxy

-- Get rid of the script, leave the arguments only
arg[0] = nil

function Proxy.new()
  local self = {}
  setmetatable(self, Proxy)

  self:init_socket()
  return self
end

function Proxy:start()
  self:start_job()
  self:start_stdin()
  self:start_socket()
end

function Proxy:start_job()
  local opts = {
    pty = true,
    env = {
      TERM = vim.env.TERM
    },

    on_stdout = function(_, d, _)
      local nl = ''
      for i, chunk in ipairs(d) do
        if chunk ~= '' or i ~= 1 then
          self:on_stdout(nl)
          self:on_stdout(chunk)
        end
        nl = '\n'
      end
    end,

    on_exit = function(_, c, _)
      os.exit(c)
    end
  }

  self.job_id = assert(vim.fn.jobstart(arg, opts))
end

function Proxy:start_stdin()
  self.stdin = uv.new_tty(0, true)            -- 0 represents stdin file descriptor
  local result, error_msg = self.stdin:set_mode(1)  -- uv.TTY_MODE_RAW
  assert(result, error_msg)

  self.stdin:read_start(vim.schedule_wrap(function(err, chunk)
    assert(not err, err)

    if chunk then
      vim.fn.chansend(self.job_id, chunk)
    else
      -- End of input, process the data
      self.stdin:close()
    end
  end))
end

function Proxy:init_socket()
  if arg[1] ~= '-a' then
    return
  end
  self.sock = assert(uv.new_udp())
  assert(self.sock:bind("127.0.0.1", 0))
  local sockname = self.sock:getsockname()
  local f = assert(io.open(arg[2], 'w'))
  f:write(sockname.port)
  f:close()

  -- The argument has been consumed, shift by two
  for i = 3, #arg do
    arg[i - 2] = arg[i]
  end
  arg[#arg] = nil
  arg[#arg] = nil
end

function Proxy:start_socket()
  if self.sock == nil then
    return
  end
  self.sock:recv_start(function(err, data, addr)
    assert(not err, err)
  end)
end

function Proxy:on_stdout(data)
  io.stdout:write(data)
end

do
  local proxy = Proxy.new()
  proxy:start()
  vim.wait(10^9, function() return false end)
end
