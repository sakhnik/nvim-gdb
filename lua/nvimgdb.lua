-- vim: set sw=2 ts=2 et:

local log = require 'nvimgdb.log'
local Config = require 'nvimgdb.config'
local Keymaps = require 'nvimgdb.keymaps'
local Cursor = require 'nvimgdb.cursor'

local instances = {}

local C = {}
C.efmmgr = require 'nvimgdb.efmmgr'
C.__index = C

-- Create a new instance of the debugger in the current tabpage.
function C.new(backend_name)
  local tab = vim.api.nvim_get_current_tabpage()
  log.info("New session " .. backend_name .. " -> " .. tab)
  local self = setmetatable({}, C)
  self.config = Config.new()
  -- Get the selected backend module
  self.backend = require "nvimgdb.backend".choose(backend_name)
  -- Initialize the keymaps subsystem
  self.keymaps = Keymaps.new(self.config)
  -- Initialize current line tracking
  self.cursor = Cursor.new(self.config)
  -- Setup 'errorformat' for the given backend.
  C.efmmgr.setup(self.backend.get_error_formats())
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

  -- Remove from 'errorformat' for the given backend.
  C.efmmgr.teardown(self.backend.get_error_formats())

  -- Clean up the current line sign
  self.cursor:hide()

  instances[tab] = nil
  if #instances == 0 then
    C.efmmgr.cleanup()
  end
end

return C
