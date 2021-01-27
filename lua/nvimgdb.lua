-- vim: set sw=2 ts=2 et:

local log = require 'nvimgdb.log'

local apps = {}

local C = {}
C.efmmgr = require 'nvimgdb.efmmgr'
C.__index = C

-- Create a new instance of the debugger in the current tabpage.
function C.new(backend_name, proxy_cmd, client_cmd)
  local tab = vim.api.nvim_get_current_tabpage()
  log.info("New session " .. backend_name .. " -> " .. tab)
  local app = require'nvimgdb.app'.new(backend_name, proxy_cmd, client_cmd)
  apps[tab] = app
  return app
end

Trap = {}
Trap.__index = function(obj, key)
  return Trap.new(key)
end

function Trap.new(key)
  log.warn("Missing key " .. key)
  local self = {}
  setmetatable(self, Trap)
  return self
end

-- Access the current instance of the debugger.
function C.i()
  local tab = vim.api.nvim_get_current_tabpage()
  local inst = apps[tab]
  if inst == nil then
    return Trap.new("tabpage " .. tab)
  end
  return inst
end

-- Cleanup the current instance.
function C.cleanup(tab)
  log.info("Cleanup session " .. tab)
  app = apps[tab]

  app:cleanup()

  apps[tab] = nil
  if #apps == 0 then
    C.efmmgr.cleanup()
  end
end

return C
