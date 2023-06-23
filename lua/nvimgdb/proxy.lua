-- Connection to the side channel.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local uv = vim.loop
local Queue = require'nvimgdb.utils.queue'

-- @class Proxy @proxy to the side channel
-- @field private client Client @debugger terminal job
-- @field private proxy_addr string @path to the file with proxy port
-- @field private sock any @UDP socket used to communicate with the proxy
-- @field private server_port number @UDP port of the proxy
-- @field private queue Queue @response queue from the proxy
local Proxy = {}
Proxy.__index = Proxy

-- Constructor
-- @param client Client @debugger terminal job
-- @return Proxy
function Proxy.new(client)
  log.debug({"function Proxy.new(", client, ")"})
  local self = setmetatable({}, Proxy)
  self.client = client
  self.proxy_addr = client:get_proxy_addr()

  self.sock = assert(uv.new_udp())
  assert(uv.udp_bind(self.sock, "127.0.0.1", 0))
  -- Will connect to the socket later, when the first query is needed
  -- to be issued.
  self.server_port = nil

  self.queue = Queue.new()
  return self
end

-- Destructor
function Proxy:cleanup()
  log.debug({"function Proxy:cleanup()"})
  if self.port ~= nil then
    uv.udp_recv_stop(self.sock)
    self.port = nil
  end
  if self.sock ~= nil then
    self.sock:close()
    self.sock = nil
  end
  self.queue:cleanup()
end

-- Get the proxy port to prepare for communication
-- @return boolean @true if the port is available -- the proxy is ready
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
  self.server_port = tonumber(line)
  local res, errmsg = uv.udp_recv_start(self.sock, function(err, data, --[[addr]]_, --[[flags]]_)
    if err ~= nil or data ~= nil then
      self.queue:put({err, data})
    end
  end)
  if res == nil then
    log.error({"Failed to start receiving from proxy", errmsg})
    self.server_port = nil
    return false
  end
  return true
end

-- Send a request to the proxy and wait for the response.
-- @param request string @command to the debugger proxy
-- @return string @response from the debugger proxy
function Proxy:query(request)
  log.debug({"function Proxy:query(", request, ")"})
  log.info("Query " .. request)

  if not self.client.is_active then
    return ''
  end

  -- It takes time for the proxy to open a side channel.
  -- So we're connecting to the socket lazily during
  -- the first query.
  if not self:_ensure_connected() then
    log.error("Server port isn't known yet")
    return ''
  end

  local res, errmsg = uv.udp_send(self.sock, request, '127.0.0.1', self.server_port, function(err)
    if err ~= nil then
      self.queue:put({err, ""})
      return
    end
  end)
  if res == nil then
    log.error({"Failed to send to proxy", errmsg})
    self.queue:put({"Failed to send", ""})
  end

  local function response_ready()
    return self.queue:peek() ~= nil
  end

  local success = vim.wait(500, response_ready, 50)
  if success then
    local err, resp = unpack(self.queue:take())

    if err ~= nil then
      log.error({"Failed to query: ", err})
      return ''
    end
    return resp
  end

  self.queue:skip()
  log.warn("Timeout querying")
  return ""
end

return Proxy
