local Config = require 'nvimgdb.config'
local Keymaps = require 'nvimgdb.keymaps'

local instances = {}

local C = {}
C.__index = C

-- Create a new instance of the debugger in the current tabpage.
function C.new()
    local self = setmetatable({}, C)
    self.config = Config.new()
    -- Initialize the keymaps subsystem
    self.keymaps = Keymaps.new(self.config)
    instances[vim.api.nvim_get_current_tabpage()] = self
    return self
end

-- Access the current instance of the debugger.
function C.i()
    inst = instances[vim.api.nvim_get_current_tabpage()]
    return inst
end

-- Cleanup the current instance.
function C.cleanup()
    instances[vim.api.nvim_get_current_tabpage()] = nil
end

return C
