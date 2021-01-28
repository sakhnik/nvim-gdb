local log = require 'nvimgdb.log'

local C = {}
C.efmmgr = require 'nvimgdb.efmmgr'
C.__index = C

-- Create a new instance of the debugger in the current tabpage.
function C.new(backend_name, proxy_cmd, client_cmd)
  local self = setmetatable({}, C)

  self.config = require'nvimgdb.config'.new()

  -- Get the selected backend module
  self.backend = require "nvimgdb.backend".choose(backend_name)

  -- Go to the other window and spawn gdb client
  self.client = require'nvimgdb.client'.new(proxy_cmd, client_cmd)

  -- Initialize connection to the side channel
  self.proxy = require'nvimgdb.proxy'.new(self.client)

  -- Initialize breakpoint tracking
  self.breakpoint = require'nvimgdb.breakpoint'.new(self.config, self.proxy, self.backend.query_breakpoints)

  -- Initialize the keymaps subsystem
  self.keymaps = require'nvimgdb.keymaps'.new(self.config)

  -- Initialize current line tracking
  self.cursor = require'nvimgdb.cursor'.new(self.config)

  -- Initialize the windowing subsystem
  self.win = require'nvimgdb.win'.new(self.config, self.keymaps, self.cursor, self.client, self.breakpoint)

  -- Initialize the parser
  parser_actions = require'nvimgdb.parser_actions'.new(self.cursor, self.win)
  self.parser = self.backend.create_parser(parser_actions)

  -- Setup 'errorformat' for the given backend.
  C.efmmgr.setup(self.backend.get_error_formats())

  return self
end

-- Cleanup the current instance.
function C:cleanup()
  -- Remove from 'errorformat' for the given backend.
  C.efmmgr.teardown(self.backend.get_error_formats())

  -- Clean up the breakpoint signs
  self.breakpoint:reset_signs()

  -- Clean up the current line sign
  self.cursor:hide()

  -- Clean up the windows and buffers
  self.win:cleanup()

  -- Close connection to the side channel
  self.proxy:cleanup()

  -- Close the debugger backend
  self.client:cleanup()
end

return C
