local log = require 'nvimgdb.log'

local C = {}
C.efmmgr = require 'nvimgdb.efmmgr'
C.__index = C

-- Create a new instance of the debugger in the current tabpage.
function C.new(backend_name, proxy_cmd, client_cmd)
  local self = setmetatable({}, C)

  self.config = require'nvimgdb.config'.new()

  -- The last executed debugger command for testing
  self._last_command = nil

  -- Create new tab for the debugging view and split horizontally
  vim.cmd('tabnew')
  vim.wo.winfixwidth = false
  vim.wo.winfixheight = false
  vim.cmd('silent wincmd o')

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

  -- Start insert mode in the GDB window
  vim.fn.feedkeys("i")

  return self
end

-- Spawn the debugger, the parser should be ready by now.
function C:start()
  -- Set initial keymaps in the terminal window.
  self.keymaps:dispatch_set_t()
  self.keymaps:dispatch_set()

  self.client:start()
  vim.cmd("doautocmd User NvimGdbStart")
end

-- Finish up the debugging session.
function C:cleanup(tab)
  vim.cmd("doautocmd User NvimGdbCleanup")

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

  -- Close the windows and the tab
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    if tabpage == tab then
      vim.cmd("tabclose! " .. vim.api.nvim_tabpage_get_number(tabpage))
      break
    end
  end
end

-- Send a command to the debugger.
function C:send(cmd, a1, a2, a3)
  if cmd ~= nil then
    local command = self.backend:translate_command(cmd):format(a1, a2, a3)
    self.client:send_line(command)
    self._last_command = command  -- Remember the command for testing
  else
    self.client:interrupt()
  end
end

-- Execute a custom debugger command and return its output.
function C:custom_command(cmd)
  return self.proxy:query('handle-command ' .. cmd)
end

return C
