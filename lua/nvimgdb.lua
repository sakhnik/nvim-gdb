-- vim: set et sw=2 ts=2:

local log = require 'nvimgdb.log'

-- @class NvimGdb @globally accessible plugin entry point
-- @field public efmmgr EfmMgr @errorformat manager
-- @field private apps table<number, App> @collection of debugger sessions {tabpage -> App}
-- @field private apps_size number @count of running debugger sessions
NvimGdb = {
  efmmgr = require 'nvimgdb.efmmgr',
  apps = {},
  apps_size = 0,
}
NvimGdb.__index = NvimGdb
NvimGdb.proxy_ready = {}

-- Create a new instance of the debugger in the current tabpage.
-- @param backend_name string @debugger kind
-- @param client_cmd string[] @debugger launch command
function NvimGdb.new(backend_name, client_cmd)
  log.info("New session " .. backend_name)
  local app = require'nvimgdb.app'.new(backend_name, client_cmd)
  local tab = vim.api.nvim_get_current_tabpage()
  log.info({"Tabpage", tab})
  NvimGdb.apps[tab] = app
  NvimGdb.apps_size = NvimGdb.apps_size + 1
  if NvimGdb.apps_size == 1 then
    -- Initialize the UI commands, autocommands etc
    log.info("Calling nvimgdb#GlobalInit()")
    vim.fn["nvimgdb#GlobalInit"]()
  end
  -- Initialize the rest of the app
  app:postinit()
end

local Trap = {}
setmetatable(Trap, {__index = function(t, k)
  return function(...)
    log.warn({"Missing key", k, {...}})
    return t
  end
end})

local SilentTrap = {}
setmetatable(SilentTrap, {__index = function(t, _)
  return function() return t end
end})

-- Access debugger instance in current tabpage.
-- @param silent boolean @false to not complain to the log if no debugging in this tabpage
-- @return App
function NvimGdb.i(silent)
  local tab = vim.api.nvim_get_current_tabpage()
  local inst = NvimGdb.apps[tab]
  if inst == nil then
    if silent ~= nil then
      return SilentTrap.foo()
    else
      return Trap.tabpage(tab, silent)
    end
  end
  return inst
end

function NvimGdb.parser_feed(tab, lines)
  local inst = NvimGdb.apps[tab]
  inst.parser:feed(lines)
end

-- Execute func while preserving the original value of the option 'hidden'
-- @param func fun()
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
-- @param tab number @tabpage handle
function NvimGdb.cleanup(tab)
  log.info("Cleanup session " .. tab)
  local app = NvimGdb.apps[tab]

  if app ~= nil then
    NvimGdb.apps[tab] = nil
    NvimGdb.apps_size = NvimGdb.apps_size - 1
    with_saved_hidden(function()
      if NvimGdb.apps_size == 0 then
        -- Cleanup commands, autocommands etc
        log.info("Calling nvimgdb#GlobalCleanup()")
        vim.fn["nvimgdb#GlobalCleanup"]()
        NvimGdb.efmmgr.cleanup()
        app.win:unset_keymaps()
      end
      app:cleanup(tab)
    end)
  end
end

-- Peek into the application count for testing
-- @return number @count of debugger sessions
function NvimGdb.get_app_count()
  return NvimGdb.apps_size
end

-- Handle the function GdbHandleTabClosed
function NvimGdb.on_tab_closed()
  log.info("Handle TabClosed")
  local active_tabs = vim.api.nvim_list_tabpages()
  local active_tabs_set = {}
  for _, tab in ipairs(active_tabs) do
    active_tabs_set[tab] = true
  end
  for tab, _ in pairs(NvimGdb.apps) do
    if active_tabs_set[tab] == nil then
      NvimGdb.cleanup(tab)
    end
  end
end

-- Handle function GdbHandleVimLeavePre
function NvimGdb.on_vim_leave_pre()
  log.info("Handle VimLeavePre")
  for tab, _ in pairs(NvimGdb.apps) do
    NvimGdb.cleanup(tab)
  end
end

return NvimGdb
