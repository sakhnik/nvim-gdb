local uv = vim.loop
local log = require'nvimgdb.log'

local is_windows = uv.os_uname().sysname:find('Windows') ~= nil
local cmd_nl = is_windows and '\r\n' or '\n'

---@alias Request {req_id: integer, command: string, addr: Address}
---@alias Address {ip: string, port: integer}

---@class ProxyImpl
---@field private prompt string prompt pattern to detect end of response
---@field private stdin userdata uv tty handle
---@field private sock userdata uv udp handle to receive requests
---@field private command_buffer string whatever the user is typing after the last newline
---@field private last_command string the last command executed by user
---@field private stdout_timer userdata uv timer to detect stdout silence
---@field private request_timer userdata uv timer to give a request deadline
---@field private request_queue table<integer, {request: string, addr: Address}> the queue of outstanding requests
---@field private request_queue_head integer the point of taking from the queue
---@field private request_queue_tail integer the point of putting to the queue
---@field private current_request Request the request currently being executed
---@field private buffer string the stdout output collected for the current request so far
local ProxyImpl = { }
ProxyImpl.__index = ProxyImpl

-- Get rid of the script, leave the arguments only
arg[0] = nil

---Constructor
---@param prompt string prompt pattern
---@return ProxyImpl
function ProxyImpl.new(prompt)
  log.info({"ProxyImpl.new", promp = prompt, arg = arg})
  local self = {}
  setmetatable(self, ProxyImpl)
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

---Start operation
function ProxyImpl:start()
  log.debug({"ProxyImpl:start"})
  self:start_job()
  self:start_stdin()
  self:start_socket()
end

---Start the debugger using the command line arguments
---@private
function ProxyImpl:start_job()
  log.debug({"ProxyImpl:start_job"})
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

---Start listening for the user input
---@private
function ProxyImpl:start_stdin()
  log.debug({"ProxyImpl:start_stdin"})
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

---Init the udp socket to receive requests
---@private
function ProxyImpl:init_socket()
  log.debug({"ProxyImpl:init_socket"})
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

---Start receiving requests via the udp socket
---@private
function ProxyImpl:start_socket()
  log.debug({"ProxyImpl:start_socket"})
  if self.sock == nil then
    return
  end
  self.sock:recv_start(function(err, data, addr)
    log.debug({"recv request", err = err, data = data, addr = addr})
    assert(not err, err)
    if data then
      self.request_queue[self.request_queue_tail] = {request = data, addr = addr}
      self.request_queue_tail = self.request_queue_tail + 1
      -- If the user doesn't type anymore, can process the request immediately,
      -- otherwise, the request will be picked up upon the stdout timer elapse.
      if self.stdout_timer:get_due_in() == 0 then
        vim.schedule(function()
          self:process_request()
        end)
      end
    end
  end)
end

---Process debugger output: either print on the screen or capture as a response to a request
---@private
---@param data1 string part 1 (""|"\n")
---@param data2 string part 2
function ProxyImpl:on_stdout(data1, data2)
  log.debug({"ProxyImpl:on_stdout", data1 = data1, data2 = data2})
  if self.current_request ~= nil then
    self.buffer = self.buffer .. data1 .. data2
    -- First substitute cursor movement with new lines: \27[16;9H
    local plain_buffer = self.buffer:gsub('%[%d+;%d+H', '\n')
    -- Get rid of the other CSEQ
    plain_buffer = plain_buffer:gsub('%[[^a-zA-Z]*[a-zA-Z]', '')
    local start_index = plain_buffer:find(self.prompt)
    if start_index then
      local request = self.current_request
      self.current_request = nil
      local response = plain_buffer:sub(#request.command + 1, start_index):match('^%s*(.-)%s*$')
      log.info({"Collected response", response = response})
      self.request_timer:stop()
      self:send_response(request.req_id, response, request.addr)
      self.buffer = ''
      -- Resume taking user input
      self:start_stdin()
      self:process_request()
    end
  else
    io.stdout:write(data1, data2)
  end
  local function start_stdout_timer()
    self.stdout_timer:stop()
    self.stdout_timer:start(100, 0, vim.schedule_wrap(function()
      if self:process_request() then
        self.stdout_timer:stop()
      else
        -- There're still requests to be scheduled
        -- Note, that interval timer returns deceptional get_due_in(),
        -- which is >0 after the timer has been stopped until the first interval elapses.
        -- Therefore no intervals, restarting the timer manually
        start_stdout_timer()
      end
    end))
    start_stdout_timer()
  end
end

---Check if there's an outstanding request and start executing it
---@private
---@return boolean false if there's an outstanding request, but it can't be scheduled at the moment
function ProxyImpl:process_request()
  log.debug({"ProxyImpl:process_request"})
  if self.current_request ~= nil then
    return false
  end
  if self.request_queue_tail == self.request_queue_head then
    return true
  end
  local command = self.request_queue[self.request_queue_head]
  self.request_queue[self.request_queue_head] = nil
  self.request_queue_head = self.request_queue_head + 1
  local req_id, _, cmd = command.request:match('(%d+) ([a-z-]+) (.+)')
  self.current_request = {req_id = assert(tonumber(req_id)), command = cmd, addr = command.addr}
  -- Going to execute a command, suppress user input
  self.stdin:read_stop()
  log.info({"Send request", cmd = cmd})
  -- \r\n for win32
  vim.fn.chansend(self.job_id, cmd .. cmd_nl)
  self.request_timer:start(500, 0, vim.schedule_wrap(function()
    self.request_timer:stop()
    self:send_response(req_id, "Timed out", command.addr)
    self.current_request = nil
    if self.buffer ~= nil then
      self:on_stdout(self.buffer, '')
      self.buffer = nil
    end
    -- Resume taking user input
    self:start_stdin()
    self:process_request()
  end))
  return true
end

---Send a response back to the requester
---@private
---@param req_id integer request identifier from the requester
---@param response any to be encoded in JSON
---@param addr Address the request origin -- the response destination
function ProxyImpl:send_response(req_id, response, addr)
  log.debug({"ProxyImpl:send_response", req_id = req_id, response = response, addr = addr})
  local data = vim.fn.json_encode({request = req_id, response = response})
  self.sock:send(data, addr.ip, addr.port, function(err)
    assert(not err, err)
  end)
end

return ProxyImpl
