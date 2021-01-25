-- vim:sw=2 ts=2 et

local log = require 'nvimgdb.log'
local Config = require 'nvimgdb.config'
local Keymaps = require 'nvimgdb.keymaps'
local Cursor = require 'nvimgdb.cursor'

local instances = {}

local C = {}
C.__index = C

-- Create a new instance of the debugger in the current tabpage.
function C.new()
  local tab = vim.api.nvim_get_current_tabpage()
  log.info("New session " .. tab)
  local self = setmetatable({}, C)
  self.config = Config.new()
  -- Initialize the keymaps subsystem
  self.keymaps = Keymaps.new(self.config)
  -- Initialize current line tracking
  self.cursor = Cursor.new(self.config)
  instances[tab] = self
  return self
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
  local inst = instances[tab]
  if inst == nil then
    return Trap.new("tabpage " .. tab)
  end
  return inst
end

-- Cleanup the current instance.
function C.cleanup(tab)
  log.info("Cleanup session " .. tab)
  self = instances[tab]

  -- Clean up the current line sign
  self.cursor:hide()

  instances[tab] = nil
end

return C
