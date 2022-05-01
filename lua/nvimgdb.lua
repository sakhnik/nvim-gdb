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
NvimGdb.vim = require 'nvimgdb.compat'
NvimGdb.proxy_ready = {}

local function global_init()
  vim.api.nvim_create_user_command('GdbDebugStop', function(_)
    NvimGdb.cleanup(vim.api.nvim_get_current_tabpage())
  end, { desc = "End debugging session in the current tabpage" })

  vim.api.nvim_create_user_command('GdbBreakpointToggle', function(_)
    NvimGdb.i():breakpoint_toggle()
  end, { desc = "Toggle breakpoint in the cursor line" })

  vim.api.nvim_create_user_command('GdbBreakpointClearAll', function(_)
    NvimGdb.i():breakpoint_clear_all()
  end, { desc = "Clear all breakpoints" })

  vim.api.nvim_create_user_command('GdbFrame', function(_)
    NvimGdb.i():send('f')
  end, { desc = "Jump to the current point of execution" })

  vim.api.nvim_create_user_command('GdbRun', function(_)
    NvimGdb.i():send('run')
  end, { desc = "Start execution of the program being debugged" })

  vim.api.nvim_create_user_command('GdbUntil', function(_)
    NvimGdb.i():send('until %s', vim.fn.line('.'))
  end, { desc = "Run until cursor" })

  vim.api.nvim_create_user_command('GdbContinue', function(_)
    NvimGdb.i():send('c')
  end, { desc = "Continue execution of the program" })

  vim.api.nvim_create_user_command('GdbNext', function(_)
    NvimGdb.i():send('n')
  end, { desc = "Continue to the next source line in the current stack frame" })

  vim.api.nvim_create_user_command('GdbStep', function(_)
    NvimGdb.i():send('s')
  end, { desc = "Continue to the next source line" })

  vim.api.nvim_create_user_command('GdbFinish', function(_)
    NvimGdb.i():send('finish')
  end, { desc = "Return from the current function" })

  vim.api.nvim_create_user_command('GdbFrameUp', function(_)
    NvimGdb.i():send('up')
  end, { desc = "One stack frame up" })

  vim.api.nvim_create_user_command('GdbFrameDown', function(_)
    NvimGdb.i():send('down')
  end, { desc = "One stack frame down" })

  vim.api.nvim_create_user_command('GdbInterrupt', function(_)
    NvimGdb.i():send()
  end, { desc = "Interrupt execution of the program" })

  vim.api.nvim_create_user_command('GdbEvalWord', function(_)
    NvimGdb.i():send('print %s', vim.fn.expand('<cword>'))
  end, { desc = "Evaluate a <cword>" })

  local function get_expression()
    local p1 = vim.fn.getpos("'<")
    local lnum1 = p1[2]
    local col1 = p1[3]
    local p2 = vim.fn.getpos("'>")
    local lnum2 = p2[2]
    local col2 = p2[3]
    local lines = vim.fn.getline(lnum1, lnum2)
    lines[#lines] = lines[#lines]:sub(1, col2)
    lines[1] = lines[1]:sub(col1)
    return table.concat(lines, "\n")
  end

  vim.api.nvim_create_user_command('GdbEvalRange', function(_)
    NvimGdb.i():send('print %s', get_expression())
  end, { desc = "Evaluate a range", range = true })

  vim.api.nvim_create_user_command('GdbCreateWatch', function(a)
    NvimGdb.i():create_watch(a.args, a.mods)
  end, { desc = "Create a watch window for a given expression", nargs = 1 })

  vim.api.nvim_create_user_command('Gdb', function(a)
    NvimGdb.i():send(a.args)
  end, { desc = "Execute custom debugger command", nargs = 1 })

  vim.api.nvim_create_user_command('GdbLopenBacktrace', function(a)
    NvimGdb.i():lopen('backtrace', a.mods)
  end, { desc = "Open stack backtrace in the quickfix" })

  vim.api.nvim_create_user_command('GdbLopenBreakpoints', function(a)
    NvimGdb.i():lopen('breakpoints', a.mods)
  end, { desc = "Open stack backtrace in the quickfix" })

  vim.api.nvim_command [[
  function! GdbCustomCommand(cmd)
    return luaeval("NvimGdb.i():custom_command(_A[1])", [a:cmd])
  endfunction
  ]]

  local augid = vim.api.nvim_create_augroup("NvimGdb", {})
  vim.api.nvim_create_autocmd("TabEnter", {
    group = augid,
    callback = function() NvimGdb.i(0):on_tab_enter() end
  })
  vim.api.nvim_create_autocmd("TabLeave", {
    group = augid,
    callback = function() NvimGdb.i(0):on_tab_leave() end
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augid,
    callback = function() NvimGdb.i(0):on_buf_enter() end
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = augid,
    callback = function() NvimGdb.i(0):on_buf_leave() end
  })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = augid,
    callback = function() NvimGdb.on_tab_closed() end
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augid,
    callback = function() NvimGdb.on_vim_leave_pre() end
  })

  -- Define custom events
  local augid2 = vim.api.nvim_create_augroup("NvimGdbInternal", {})
  vim.api.nvim_create_autocmd("User NvimGdbQuery", { group = augid2, command = "" })
  vim.api.nvim_create_autocmd("User NvimGdbBreak", { group = augid2, command = "" })
  vim.api.nvim_create_autocmd("User NvimGdbContinue", { group = augid2, command = "" })
  vim.api.nvim_create_autocmd("User NvimGdbStart", { group = augid2, command = "" })
  vim.api.nvim_create_autocmd("User NvimGdbCleanup", { group = augid2, command = "" })
end

-- Create a new instance of the debugger in the current tabpage.
-- @param backend_name string @debugger kind
-- @param proxy_cmd string @proxy app to launch the debugger with
-- @param client_cmd string @debugger launch command
function NvimGdb.new(backend_name, proxy_cmd, client_cmd)
  log.info("New session " .. backend_name)
  local app = require'nvimgdb.app'.new(backend_name, proxy_cmd, client_cmd)
  local tab = vim.api.nvim_get_current_tabpage()
  log.info({"Tabpage", tab})
  NvimGdb.apps[tab] = app
  NvimGdb.apps_size = NvimGdb.apps_size + 1
  if NvimGdb.apps_size == 1 then
    -- Initialize the UI commands, autocommands etc
    log.info("Calling global_init()")
    global_init()
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
  if inst ~= nil then
    inst.parser:feed(lines)
  end
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

-- Shared global state cleanup after the last session ended
local function global_cleanup()
  -- Cleanup the autocommands
  vim.api.nvim_del_augroup_by_name("NvimGdb")
  -- Cleanup custom events
  vim.api.nvim_del_augroup_by_name("NvimGdbInternal")

  vim.api.nvim_command [[delfunction GdbCustomCommand]]

  -- Cleanup user commands and keymaps
  vim.api.nvim_del_user_command("GdbDebugStop")
  vim.api.nvim_del_user_command("GdbBreakpointToggle")
  vim.api.nvim_del_user_command("GdbBreakpointClearAll")
  vim.api.nvim_del_user_command("GdbFrame")
  vim.api.nvim_del_user_command("GdbRun")
  vim.api.nvim_del_user_command("GdbUntil")
  vim.api.nvim_del_user_command("GdbContinue")
  vim.api.nvim_del_user_command("GdbNext")
  vim.api.nvim_del_user_command("GdbStep")
  vim.api.nvim_del_user_command("GdbFinish")
  vim.api.nvim_del_user_command("GdbFrameUp")
  vim.api.nvim_del_user_command("GdbFrameDown")
  vim.api.nvim_del_user_command("GdbInterrupt")
  vim.api.nvim_del_user_command("GdbEvalWord")
  vim.api.nvim_del_user_command("GdbEvalRange")
  vim.api.nvim_del_user_command("GdbCreateWatch")
  vim.api.nvim_del_user_command("Gdb")
  vim.api.nvim_del_user_command("GdbLopenBacktrace")
  vim.api.nvim_del_user_command("GdbLopenBreakpoints")
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
        log.info("Calling global_cleanup()")
        global_cleanup()
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
