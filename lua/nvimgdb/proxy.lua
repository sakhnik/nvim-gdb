-- Connection to the side channel.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local uv = vim.loop

-- @class Proxy @proxy to the side channel
-- @field private client Client @debugger terminal job
-- @field private proxy_addr string @path to the file with proxy port
-- @field private sock any @UDP socket used to communicate with the proxy
-- @field private server_port number @UDP port of the proxy
local C = {}
C.__index = C

-- Constructor
-- @param client Client @debugger terminal job
-- @return Proxy
function C.new(client)
  local self = setmetatable({}, C)
  self.client = client
  self.proxy_addr = client:get_proxy_addr()

  self.sock = assert(uv.new_udp())
  assert(uv.udp_bind(self.sock, "127.0.0.1", 0))
  -- Will connect to the socket later, when the first query is needed
  -- to be issued.
  self.server_port = nil
  return self
end

-- Destructor
function C:cleanup()
  if self.sock ~= nil then
    self.sock:close()
    self.sock = nil
  end
end

-- Get the proxy port to prepare for communication
-- @return boolean @true if the port is available -- the proxy is ready
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
-- @param request string @command to the debugger proxy
-- @return string @response from the debugger proxy
function C:query(request)
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

  local o_err = nil
  local o_resp = nil
  local cur_tab = vim.api.nvim_get_current_tabpage()
  NvimGdb.proxy_ready[cur_tab] = false

  log.debug("udp_send", request, self.server_port)
  assert(uv.udp_send(self.sock, request, '127.0.0.1', self.server_port, function(err)
    if err ~= nil then
      log.debug("udp_send callback error", err)
      o_err = err
      NvimGdb.proxy_ready[cur_tab] = true
      return
    end

    log.debug("udp_recv_start")
    assert(uv.udp_recv_start(self.sock, function(err2, data, --[[addr]]_, --[[flags]]_)
        if err2 ~= nil then
          log.debug("udp_recv callback error", err2, data)
          o_err = err2
          NvimGdb.proxy_ready[cur_tab] = true
          return
        end
        if data ~= nil then
          log.debug("udp_recv callback data", err2, data)
          o_resp = data
          NvimGdb.proxy_ready[cur_tab] = true
          return
        end
        NvimGdb.proxy_ready[cur_tab] = true
        log.debug("udp_recv callback rest", err2, data)
      end))
  end))

  log.debug("wait for recv")
  if NvimGdb.vim.fn.wait(500, "luaeval('NvimGdb.proxy_ready[" .. cur_tab .. "]')", 50) ~= 0 then
    log.debug("timeout, udp_recv_stop")
    assert(uv.udp_recv_stop(self.sock))
    return ''
  end
  log.debug("udp_recv_stop")
  assert(uv.udp_recv_stop(self.sock))

  if o_err ~= nil then
    log.error("Failed to query: " .. o_err)
    return ''
  end

  log.debug("success")
  return o_resp
end

return C
