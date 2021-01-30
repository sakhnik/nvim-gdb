-- vim: set sw=2 ts=2 et:

local log = require 'nvimgdb.log'

local apps = {}

local C = {}
C.efmmgr = require 'nvimgdb.efmmgr'
C.__index = C

-- Create a new instance of the debugger in the current tabpage.
function C.new(backend_name, proxy_cmd, client_cmd)
  log.info("New session " .. backend_name)
  local app = require'nvimgdb.app'.new(backend_name, proxy_cmd, client_cmd)
  local tab = vim.api.nvim_get_current_tabpage()
  log.info({"Tabpage", tab})
  apps[tab] = app
  return app
end

local Trap = {}
Trap.__index = function(obj, key)
  return (function(...)
    log.warn(arg)
    return Trap.new(key)
  end)
end

function Trap.new(key)
  log.warn("Missing key " .. key)
  local self = setmetatable({}, Trap)
  return self
end

-- Access the current instance of the debugger.
function C.i()
  local tab = vim.api.nvim_get_current_tabpage()
  local inst = apps[tab]
  if inst == nil then
    -- TODO don't report on on_tab_enter/on_tab_leave
    return Trap.new("tabpage " .. tab)
  end
  return inst
end

-- Cleanup the current instance.
function C.cleanup(tab)
  log.info("Cleanup session " .. tab)
  local app = apps[tab]

  app:cleanup(tab)

  apps[tab] = nil
  if #apps == 0 then
    C.efmmgr.cleanup()
  end
end

function C.parser_feed(tab, content)
  local app = apps[tab]
  if app ~= nil then
    -- TODO feed chunkwise
    for i, ele in ipairs(content) do
      content[i] = ele:gsub('\x1B[@-_][0-?]*[ -/]*[@-~]', '')
    end
    app.parser:feed(content)
  end
end

return C
