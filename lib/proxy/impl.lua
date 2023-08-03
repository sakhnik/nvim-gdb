local uv = vim.loop
local log = require'nvimgdb.log'

local is_windows = uv.os_uname().sysname:find('Windows') ~= nil
local cmd_nl = is_windows and '\r\n' or '\n'

local Proxy = { }
Proxy.__index = Proxy

-- TODO: comments and docs

-- Get rid of the script, leave the arguments only
arg[0] = nil

function Proxy.new(prompt)
  log.info({"Proxy.new", promp = prompt, arg = arg})
  local self = {}
  setmetatable(self, Proxy)
  self.prompt = prompt

  self.stdin = uv.new_tty(0, true)            -- 0 represents stdin file descriptor
  local result, error_msg = self.stdin:set_mode(1)  -- uv.TTY_MODE_RAW
  assert(result, error_msg)

  self:init_socket()

  self.command_buffer = ''
  self.last_command = ''

  self.stdout_timer = assert(uv.new_timer())
  self.request_timer = assert(uv.new_timer())
  self.request_queue = {}
  self.request_queue_head = 1
  self.request_queue_tail = 1
  self.current_request = nil
  self.buffer = ""
  return self
end

function Proxy:start()
  log.debug({"Proxy:start"})
  self:start_job()
  self:start_stdin()
  self:start_socket()
end

function Proxy:start_job()
  log.debug({"Proxy:start_job"})
  local width = self.stdin:get_winsize()

  local opts = {
    pty = true,
    env = {
      TERM = vim.env.TERM
    },
    width = width,

    on_stdout = function(_, d, _)
      local nl = ''
      for i, chunk in ipairs(d) do
        if chunk ~= '' or i ~= 1 then
          self:on_stdout(nl, chunk)
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
  log.debug({"Proxy:start_stdin"})
  self.stdin:read_start(vim.schedule_wrap(function(err, chunk)
    log.debug({"stdin:read", err = err, chunk = chunk})
    assert(not err, err)

    if chunk then
      -- Accumulate whatever the user is typing to track the last command entered
      self.command_buffer = self.command_buffer .. chunk
      local start_index, end_index = self.command_buffer:find('[\n\r]+')
      if start_index then
        if start_index == 1 then
          -- Send previous command
          log.debug({"send previous", command = self.last_command})
          vim.fn.chansend(self.job_id, self.last_command)
        else
          -- Remember the command
          self.last_command = self.command_buffer:sub(1, start_index - 1)
          log.debug({"remember command", self.last_command})
        end
        -- Reset the command buffer
        self.command_buffer = self.command_buffer:sub(end_index + 1)
      end
      vim.fn.chansend(self.job_id, chunk)
    else
      -- End of input, process the data
      self.stdin:close()
    end
  end))
end

function Proxy:init_socket()
  log.debug({"Proxy:init_socket"})
  if arg[1] ~= '-a' then
    return
  end
  self.sock = assert(uv.new_udp())
  assert(self.sock:bind("127.0.0.1", 0))
  local sockname = self.sock:getsockname()
  log.info({"Socket port", port = sockname.port})
  local f = assert(io.open(arg[2], 'w'))
  f:write(sockname.port)
  f:close()

  -- The argument has been consumed, shift by two
  for i = 3, #arg do
    arg[i - 2] = arg[i]
  end
  arg[#arg] = nil
  arg[#arg] = nil
  log.debug({"shift arg", arg = arg})
end

function Proxy:start_socket()
  log.debug({"Proxy:start_socket"})
  if self.sock == nil then
    return
  end
  self.sock:recv_start(function(err, data, addr)
    log.debug({"recv request", err = err, data = data, addr = addr})
    assert(not err, err)
    if data then
      self.request_queue[self.request_queue_tail] = {data, addr}
      self.request_queue_tail = self.request_queue_tail + 1
    end
  end)
end

function Proxy:on_stdout(data1, data2)
  log.debug({"Proxy:on_stdout", data1 = data1, data2 = data2})
  if self.current_request ~= nil then
    self.buffer = self.buffer .. data1 .. data2
    local plain_buffer = self.buffer:gsub('%[[^a-zA-Z]*[a-zA-Z]', '')
    local start_index = plain_buffer:find(self.prompt)
    if start_index then
      local req_id, cmd, addr = unpack(self.current_request)
      local response = plain_buffer:sub(#cmd + 1, start_index):match('^%s*(.-)%s*$')
      log.info({"Collected response", response = response})
      self.request_timer:stop()
      self:send_response(req_id, response, addr)
      self.buffer = ''
      self.current_request = nil
      self:process_command()
    end
  else
    io.stdout:write(data1, data2)
  end
  self.stdout_timer:stop()
  self.stdout_timer:start(100, 100, vim.schedule_wrap(function()
    self:process_command()
  end))
end

function Proxy:process_command()
  log.debug({"Proxy:process_command"})
  if self.current_request ~= nil then
    return
  end
  self.stdout_timer:stop()
  if self.request_queue_tail == self.request_queue_head then
    return
  end
  local command = self.request_queue[self.request_queue_head]
  local addr = command[2]
  self.request_queue[self.request_queue_head] = nil
  self.request_queue_head = self.request_queue_head + 1
  local req_id, _, cmd = command[1]:match('(%d+) ([a-z-]+) (.+)')
  self.current_request = {tonumber(req_id), cmd, addr}
  log.info({"Send request", cmd = cmd})
  -- \r\n for win32
  vim.fn.chansend(self.job_id, cmd .. cmd_nl)
  self.request_timer:start(500, 0, vim.schedule_wrap(function()
    self.request_timer:stop()
    self:send_response(req_id, "Timed out", addr)
    self.current_request = nil
    if self.buffer ~= nil then
      self:on_stdout(self.buffer, '')
      self.buffer = nil
    end
    self:process_command()
  end))
end

function Proxy:send_response(req_id, response, addr)
  log.debug({"Proxy:send_response", req_id = req_id, response = response, addr = addr})
  local data = vim.fn.json_encode({request = req_id, response = response})
  self.sock:send(data, addr.ip, addr.port, function(err)
    assert(not err, err)
  end)
end

return Proxy
