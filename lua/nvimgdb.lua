-- vim: set et sw=2 ts=2:

local log = require 'nvimgdb.log'

---@class NvimGdb globally accessible plugin entry point
---@field public efmmgr EfmMgr errorformat manager
---@field private apps table<number, App> collection of debugger sessions {tabpage -> App}
---@field private apps_size number count of running debugger sessions

-- Global instance
NvimGdb = {
  efmmgr = require 'nvimgdb.efmmgr',
  apps = {},
  apps_size = 0,
  mt = {},
}

setmetatable(NvimGdb, NvimGdb.mt)

NvimGdb.mt.__index = function(self, key)
  if key == 'here' then
    return self.i()
  end
end

---Create a new instance of the debugger in the current tabpage.
---@param backend_name string debugger kind
---@param client_cmd string[] debugger launch command
function NvimGdb.new(backend_name, client_cmd)
  log.info({"NvimGdb.new", backend_name = backend_name, client_cmd = client_cmd})
  local app = require'nvimgdb.app'.new(backend_name, client_cmd)
  local tab = vim.api.nvim_get_current_tabpage()
  log.info({"Tabpage", tab})
  NvimGdb.apps[tab] = app
  NvimGdb.apps_size = NvimGdb.apps_size + 1
  if NvimGdb.apps_size == 1 then
    -- Initialize the UI commands, autocommands etc
    NvimGdb.global_init()
  end
  -- Initialize the rest of the app
  app:postinit()
end

local TrapClass = {
  __index = function(self, k)
    if not self.silent then
      log.warn({"Missing key", k})
    end
    return self
  end,
  __call = function(self, ...)
    if not self.silent then
      log.warn({"Call", ...})
    end
    return self
  end
}

local Trap = {silent = false}
setmetatable(Trap, TrapClass)
local SilentTrap = {silent = true}
setmetatable(SilentTrap, TrapClass)


---Access debugger instance in current tabpage.
---@param silent any? false|0 to not complain to the log if no debugging in this tabpage
---@return App?
function NvimGdb.i(silent)
  local tab = vim.api.nvim_get_current_tabpage()
  local inst = NvimGdb.apps[tab]
  if inst ~= nil then
    return inst
  end
  return silent ~= nil and SilentTrap or Trap
end

---Process debugger output
---@param tab number tabpage number
---@param lines string[]
function NvimGdb.parser_feed(tab, lines)
  local app = NvimGdb.apps[tab]
  app:get_parser():feed(lines)
end

---Execute func while preserving the original value of the option 'hidden'
---@param func function()
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

---Cleanup the current instance.
---@param tab number tabpage handle
function NvimGdb.cleanup(tab)
  log.info({"NvimGdb.cleanup", tab = tab})
  local app = NvimGdb.apps[tab]

  if app ~= nil then
    NvimGdb.apps[tab] = nil
    NvimGdb.apps_size = NvimGdb.apps_size - 1
    with_saved_hidden(function()
      if NvimGdb.apps_size == 0 then
        -- Cleanup commands, autocommands etc
        NvimGdb.global_cleanup()
        NvimGdb.efmmgr.cleanup()
        app:get_win():unset_keymaps()
      end
      app:cleanup(tab)
    end)
  end
end

---Peek into the application count for testing
---@return number count of debugger sessions
function NvimGdb.get_app_count()
  return NvimGdb.apps_size
end

---Handle the function GdbHandleTabClosed
function NvimGdb.on_tab_closed()
  log.info({"NvimGdb.on_tab_closed"})
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

---Handle function GdbHandleVimLeavePre
function NvimGdb.on_vim_leave_pre()
  log.info({"NvimGdb.on_vim_leave_pre"})
  for tab, _ in pairs(NvimGdb.apps) do
    NvimGdb.cleanup(tab)
  end
end


---Shared global state initialization (commands, keymaps etc)
function NvimGdb.global_init()
  log.info({"NvimGdb.global_init"})
  vim.api.nvim_create_user_command('GdbDebugStop',
    function() NvimGdb.cleanup(vim.api.nvim_get_current_tabpage()) end,
    {force = true, desc = 'Stop current debugging session'})
  vim.api.nvim_create_user_command('GdbBreakpointToggle',
    function() NvimGdb.here:breakpoint_toggle() end,
    {force = true, desc = 'Toggle a breakpoint in the current line'})
  vim.api.nvim_create_user_command('GdbBreakpointClearAll',
    function() NvimGdb.here:breakpoint_clear_all() end,
    {force = true, desc = 'Clear all breakpoints'})
  vim.api.nvim_create_user_command('GdbFrame',
    function() NvimGdb.here:send('f') end,
    {force = true, desc = 'Go to the current frame'})
  vim.api.nvim_create_user_command('GdbRun',
    function() NvimGdb.here:send('run') end,
    {force = true, desc = 'Run the debugged program'})
  vim.api.nvim_create_user_command('GdbUntil',
    function() NvimGdb.here:send('until %s', vim.fn.line('.')) end,
    {force = true, desc = 'Continue program execution until the current line'})
  vim.api.nvim_create_user_command('GdbContinue',
    function() NvimGdb.here:send('c') end,
    {force = true, desc = 'Continue program execution'})
  vim.api.nvim_create_user_command('GdbNext',
    function() NvimGdb.here:send('n') end,
    {force = true, desc = 'Step over'})
  vim.api.nvim_create_user_command('GdbStep',
    function() NvimGdb.here:send('s') end,
    {force = true, desc = 'Step into'})
  vim.api.nvim_create_user_command('GdbFinish',
    function() NvimGdb.here:send('finish') end,
    {force = true, desc = 'Finish executing current frame'})
  vim.api.nvim_create_user_command('GdbFrameUp',
    function() NvimGdb.here:send('up') end,
    {force = true, desc = 'Up one frame'})
  vim.api.nvim_create_user_command('GdbFrameDown',
    function() NvimGdb.here:send('down') end,
    {force = true, desc = 'Down one frame'})
  vim.api.nvim_create_user_command('GdbInterrupt',
    function() NvimGdb.here:send() end,
    {force = true, desc = 'Interrupt running program'})
  vim.api.nvim_create_user_command('GdbEvalWord',
    function() NvimGdb.here:send('print %s', vim.fn.expand('<cword>')) end,
    {force = true, desc = 'Evaluate the word under cursor'})

  local function get_expression()
    local _, lnum1, col1 = unpack(vim.fn.getpos("'<"))
    local _, lnum2, col2 = unpack(vim.fn.getpos("'>"))
    local lines = vim.fn.getline(lnum1, lnum2)
    lines[#lines] = lines[#lines]:sub(1, col2)
    lines[1] = lines[1]:sub(col1)
    return table.concat(lines, "\n")
  end

  vim.api.nvim_create_user_command('GdbEvalRange',
    function() NvimGdb.here:send('print %s', get_expression()) end,
    {range = true, force = true, desc = 'Evaluate the range'})

  vim.api.nvim_create_user_command('GdbCreateWatch',
    function(a) NvimGdb.here:create_watch(a.args, a.mods) end,
    {nargs = 1, force = true, desc = 'Create a window watching an expression'})
  vim.api.nvim_create_user_command('Gdb',
    function(a) NvimGdb.here:send(a.args) end,
    {nargs = "+", force = true, desc = 'Execute debugger command'})
  vim.api.nvim_create_user_command('GdbLopenBacktrace',
    function(a) NvimGdb.here:lopen(require'nvimgdb.app'.lopen_kind.backtrace, a.mods) end,
    {force = true, desc = 'Load backtrace frame locations into the location list'})
  vim.api.nvim_create_user_command('GdbLopenBreakpoints',
    function(a) NvimGdb.here:lopen(require'nvimgdb.app'.lopen_kind.breakpoints, a.mods) end,
    {force = true, desc = 'Load breakpoint locations into the location list'})

  vim.cmd([[
    function! GdbCustomCommand(cmd)
      echo "GdbCustomCommand() is deprecated, use Lua `require'nvimgdb'.i(0):custom_command_async()`"
      return luaeval("NvimGdb.here:custom_command(_A[1])", [a:cmd])
    endfunction

    augroup NvimGdb
      au!
      au TabEnter * lua require'nvimgdb'.i(0):on_tab_enter()
      au TabLeave * lua require'nvimgdb'.i(0):on_tab_leave()
      au BufEnter * lua require'nvimgdb'.i(0):on_buf_enter()
      au BufLeave * lua require'nvimgdb'.i(0):on_buf_leave()
      au TabClosed * lua require'nvimgdb'.on_tab_closed()
      au VimLeavePre * lua require'nvimgdb'.on_vim_leave_pre()
    augroup END

    " Define custom events
    augroup NvimGdbInternal
      au!
      au User NvimGdbQuery ""
      au User NvimGdbBreak ""
      au User NvimGdbContinue ""
      au User NvimGdbStart ""
      au User NvimGdbCleanup ""
    augroup END
  ]])

end

---Shared global state cleanup after the last session ended
function NvimGdb.global_cleanup()
  log.info({"NvimGdb.global_cleanup"})
  vim.cmd([[
    " Cleanup the autocommands
    augroup NvimGdb
      au!
    augroup END
    augroup! NvimGdb

  " Cleanup custom events
    augroup NvimGdbInternal
      au!
    augroup END
    augroup! NvimGdbInternal

    delfunction GdbCustomCommand
  ]])

  -- Cleanup user commands and keymaps
  vim.api.nvim_del_user_command('GdbDebugStop')
  vim.api.nvim_del_user_command('GdbBreakpointToggle')
  vim.api.nvim_del_user_command('GdbBreakpointClearAll')
  vim.api.nvim_del_user_command('GdbFrame')
  vim.api.nvim_del_user_command('GdbRun')
  vim.api.nvim_del_user_command('GdbUntil')
  vim.api.nvim_del_user_command('GdbContinue')
  vim.api.nvim_del_user_command('GdbNext')
  vim.api.nvim_del_user_command('GdbStep')
  vim.api.nvim_del_user_command('GdbFinish')
  vim.api.nvim_del_user_command('GdbFrameUp')
  vim.api.nvim_del_user_command('GdbFrameDown')
  vim.api.nvim_del_user_command('GdbInterrupt')
  vim.api.nvim_del_user_command('GdbEvalWord')
  vim.api.nvim_del_user_command('GdbEvalRange')
  vim.api.nvim_del_user_command('GdbCreateWatch')
  vim.api.nvim_del_user_command('Gdb')
  vim.api.nvim_del_user_command('GdbLopenBacktrace')
  vim.api.nvim_del_user_command('GdbLopenBreakpoints')
end

return NvimGdb
