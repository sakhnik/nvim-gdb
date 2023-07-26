-- Connection to the side channel.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local uv = vim.loop

---@class Proxy proxy to the side channel
---@field private client Client debugger terminal job
---@field private proxy_addr string path to the file with proxy port
---@field private sock any UDP socket used to communicate with the proxy
---@field private server_port number UDP port of the proxy
---@field private request_id number sequential request number
---@field private responses table<number, any> received responses
---@field private responses_size number count of responses being waited
local Proxy = {}
Proxy.__index = Proxy

---Constructor
---@param client Client debugger terminal job
---@return Proxy
function Proxy.new(client)
  log.debug({"Proxy.new"})
  local self = setmetatable({}, Proxy)
  self.client = client
  self.proxy_addr = client:get_proxy_addr()

  self.sock = assert(uv.new_udp())
  assert(uv.udp_bind(self.sock, "127.0.0.1", 0))
  -- Will connect to the socket later, when the first query is needed
  -- to be issued.
  self.server_port = nil

  self.request_id = 0
  self.responses = {}
  self.responses_size = 0

  return self
end

---Destructor
function Proxy:cleanup()
  log.debug({"Proxy:cleanup"})
  if self.port ~= nil then
    uv.udp_recv_stop(self.sock)
    self.port = nil
  end
  if self.sock ~= nil then
    self.sock:close()
    self.sock = nil
  end
end

---Get the proxy port to prepare for communication
---@return boolean true if the port is available -- the proxy is ready
function Proxy:_ensure_connected()
  log.debug({"function Proxy:_ensure_connected()"})
  if self.server_port ~= nil then
    return true
  end
  local success, lines = pcall(io.lines, self.proxy_addr)
  if not success then
    log.warn({self.proxy_addr, 'not available yet', lines})
    return false
  end
  local line = assert(lines())
  self.server_port = assert(tonumber(line))
  local res, errmsg = uv.udp_recv_start(self.sock, function(err, data, --[[addr]]_, --[[flags]]_)
    if err ~= nil then
      log.error({"Failed to receive response", err})
    elseif data ~= nil then
      local response = vim.json.decode(data)
      self.responses[response.request] = response
      self.responses_size = self.responses_size + 1
    end
  end)
  if res == nil then
    log.error({"Failed to start receiving from proxy", errmsg})
    self.server_port = nil
    return false
  end
  return true
end

---Send a request to the proxy and wait for the response.
---@param request string command to the debugger proxy
---@return any response from the debugger proxy
function Proxy:query(request)
  log.info({"Proxy:query", request = request})

  if not self.client.is_active then
    return nil
  end

  -- It takes time for the proxy to open a side channel.
  -- So we're connecting to the socket lazily during
  -- the first query.
  if not self:_ensure_connected() then
    log.error("Server port isn't known yet")
    return nil
  end

  if self.responses_size > 16 then
    log.debug({"Cleaning obsolete responses count=", #self.responses})
    local cleaned_responses = {}
    local cleaned_responses_size = 0
    local deadline_id = self.request_id - 16
    for id, resp in pairs(self.responses) do
      if id >= deadline_id then
        cleaned_responses[id] = resp
        cleaned_responses_size = cleaned_responses_size + 1
      end
    end
    self.responses = cleaned_responses
    self.responses_size = cleaned_responses_size
    log.debug({"Responses after cleanup count=", self.responses_size})
  end

  local request_id = self.request_id
  self.request_id = self.request_id + 1

  if self.sock == nil then
    log.error({"No socket, likely a bug"})
    return nil
  end

  local res, errmsg = uv.udp_send(self.sock, request_id .. " " .. request, '127.0.0.1', self.server_port, function(err)
    if err ~= nil then
      self.responses[request_id] = {response = {}}
      self.responses_size = self.responses_size + 1
      return
    end
  end)
  if res == nil then
    log.error({"Failed to send to proxy", errmsg})
    self.responses[request_id] = {response = {}}
    self.responses_size = self.responses_size + 1
  end

  local function response_ready()
    return self.responses[request_id] ~= nil
  end

  local success = vim.wait(500, response_ready, 50)
  if success then
    local response = self.responses[request_id].response
    self.responses[request_id] = nil
    self.responses_size = self.responses_size - 1
    return response
  end

  log.warn("Timeout querying")
  return nil
end

return Proxy
