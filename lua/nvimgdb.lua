-- vim: set sw=2 ts=2 et:

local log = require 'nvimgdb.log'

local apps = {}
local apps_size = 0

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
  apps_size = apps_size + 1
  if apps_size == 1 then
    -- Initialize the UI commands, autocommands etc
    log.info("Calling nvimgdb#GlobalInit()")
    vim.fn["nvimgdb#GlobalInit"]()
  end
  app:start()
end

local Trap = {}
setmetatable(Trap, {__index = function(t, k)
  return function(...)
    log.warn({"Missing key", k, {...}})
    return t
  end
end})

local SilentTrap = {}
setmetatable(SilentTrap, {__index = function(t, k)
  return function(...) return t end
end})

-- Access the current instance of the debugger.
function C.i(silent)
  local tab = vim.api.nvim_get_current_tabpage()
  local inst = apps[tab]
  if inst == nil then
    if silent ~= nil then
      return SilentTrap.foo()
    else
      return Trap.tabpage(tab, silent)
    end
  end
  return inst
end

local function with_saved_hidden(func)
  -- Prevent "ghost" [noname] buffers when leaving the debugger
  -- and 'hidden' is on
  local hidden = vim.o.hidden
  if hidden then
    vim.o.hidden = false
  end
  func()
  -- sets hidden back to user default
  if hidden then
    vim.o.hidden = true
  end
end

-- Cleanup the current instance.
function C.cleanup(tab)
  log.info("Cleanup session " .. tab)
  local app = apps[tab]

  if app ~= nil then
    apps[tab] = nil
    apps_size = apps_size - 1
    with_saved_hidden(function()
      if apps_size == 0 then
        -- Cleanup commands, autocommands etc
        log.info("Calling nvimgdb#GlobalCleanup()")
        vim.fn["nvimgdb#GlobalCleanup"]()
        C.efmmgr.cleanup()
      end
      app:cleanup(tab)
    end)
  end
end

-- Handle the function GdbHandleTabClosed.
function C.on_tab_closed()
  log.info("Handle TabClosed")
  local active_tabs = vim.api.nvim_list_tabpages()
  local active_tabs_set = {}
  for _, tab in ipairs(active_tabs) do
    active_tabs_set[tab] = true
  end
  for tab, app in pairs(apps) do
    if active_tabs_set[tab] == nil then
      C.cleanup(tab)
    end
  end
end

function C.on_vim_leave_pre()
  -- Handle function GdbHandleVimLeavePre.
  log.info("Handle VimLeavePre")
  for tab, _ in pairs(apps) do
    C.gdb_cleanup(tab)
  end
end

return C
