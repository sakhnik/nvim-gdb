-- The class to maintain connection to the debugger client.
-- vim: set et ts=2 sw=2:

local uv = vim.loop

local C = {}
C.__index = C

local function _get_plugin_dir()
  local path = debug.getinfo(1).source:match("@(.*/)")
  return uv.fs_realpath(path .. '/../..')
end

function C.new(proxy_cmd, client_cmd)
  local self = setmetatable({}, C)
  self.win = vim.api.nvim_get_current_win()
  self.client_id = nil
  -- Create a temporary unique directory for all the sockets.
  self.sock_dir = uv.fs_mkdtemp(uv.os_tmpdir() .. '/nvimgdb-sock-XXXXXX')
  --uv.fs_rmdir(self.sock_dir)

  -- Prepare the debugger command to run
  self.command = client_cmd
  if proxy_cmd ~= nil then
    self.proxy_addr = self.sock_dir .. '/port'
    self.command = _get_plugin_dir() .. "/lib/" .. proxy_cmd .. " -a " .. self.proxy_addr .. " -- " .. client_cmd
  end
  vim.cmd "enew"
  self.client_buf = vim.api.nvim_get_current_buf()
  return self
end

function C:cleanup()
  if vim.fn.bufexists(self.client_buf) then
    vim.api.nvim_buf_delete(self.client_buf, {["force"] = true})
  end

  if self.proxy_addr then
    os.remove(self.proxy_addr)
  end
  assert(os.remove(self.sock_dir))
end

function C:start()
  -- Open a terminal window with the debugger client command.
  -- Go to the yet-to-be terminal window
  vim.api.nvim_set_current_win(self.win)
  local cur_tabpage = vim.api.nvim_get_current_tabpage()
  local cur_window = vim.api.nvim_get_current_win()
  self.client_id = vim.fn.termopen(self.command,
    {on_stdout = function(j,d,e) nvimgdb.parser_feed(cur_tabpage, d) end,
     on_exit = function(j,c,e) if c == 0 then vim.api.nvim_win_close(cur_window, true) end end,
    })

  -- Allow detaching the terminal from its window
  vim.o.bufhidden = "hide"
  -- Finish the debugging session when the terminal is closed
  vim.cmd("au TermClose <buffer> lua nvimgdb.cleanup(" .. cur_tabpage .. ")")
end

function C:interrupt()
  -- Interrupt running program by sending ^c.
  vim.fn.jobsend(self.client_id, "\x03")
end

function C:send_line(data)
  -- Execute one command on the debugger interpreter.
  vim.fn.jobsend(self.client_id, data .. "\n")
end

-- Get the client terminal buffer.
function C:get_buf()
  return self.client_buf
end

-- Get the side-channel address.
function C:get_proxy_addr()
  return self.proxy_addr
end

return C
