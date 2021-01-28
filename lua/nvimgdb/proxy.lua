-- Connection to the side channel.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local uv = vim.loop

local C = {}
C.__index = C

-- Proxy to the side channel.
function C.new(client)
  local self = setmetatable({}, C)
  self.proxy_addr = client:get_proxy_addr()

  self.sock = assert(uv.new_udp())
  assert(uv.udp_bind(self.sock, "127.0.0.1", 0))
  --self.sock.settimeout(0.5)
  -- Will connect to the socket later, when the first query is needed
  -- to be issued.
  self.server_port = nil
  return self
end

function C:cleanup()
  if self.sock ~= nil then
    self.sock:close()
    self.sock = nil
  end
end

function C:_ensure_connected()
  if self.server_port ~= nil then
    return true
  end
  local lines = io.lines(self.proxy_addr)
  if lines == nil then
    log.warn(self.proxy_addr .. ' not available yet')
    return false
  end
  local line = assert(lines())
  self.server_port = tonumber(line)
  return true
end

-- Send a request to the proxy and wait for the response.
function C:query(request)
  log.info("Query " .. request)

  -- It takes time for the proxy to open a side channel.
  -- So we're connecting to the socket lazily during
  -- the first query.
  if not self:_ensure_connected() then
    log.error("Server port isn't known yet")
    return ''
  end

  local o_err = nil
  local o_resp = nil

  assert(uv.udp_send(self.sock, request, '127.0.0.1', self.server_port, function(err)
    if err ~= nil then
      o_err = err
      return
    end

    assert(uv.udp_recv_start(self.sock, function(err, data, addr, flags)
      if err ~= nil then
        o_err = err
        return
      end
      if data ~= nil then
        o_resp = data
      end
    end))
  end))

  local function check()
    return o_err ~= nil or o_resp ~= nil
  end

  if not vim.wait(500, check, 50) then
    assert(uv.udp_recv_stop(self.sock))
    return ''
  end
  assert(uv.udp_recv_stop(self.sock))

  if o_err ~= nil then
    log.error("Failed to query: " .. o_err)
    return ''
  end

  return o_resp
end

return C
