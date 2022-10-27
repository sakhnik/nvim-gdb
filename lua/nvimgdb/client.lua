-- The class to maintain connection to the debugger client.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local uv = vim.loop

-- @class Client @spawned debugger manager
-- @field private config Config @resolved configuration
-- @field public win number @terminal window handler
-- @field private client_id number @terminal job handler
-- @field private is_active boolean @true if the debugger has been launched
-- @field private sock_dir string @temporary directory for the proxy address
-- @field private proxy_addr string @path to the file with proxy port
-- @field private command string @complete command to launch the debugger (including proxy)
-- @field private client_buf number @terminal buffer handler
-- @field private buf_hidden_auid number @autocmd id of the BufHidden handler
local Client = {}
Client.__index = Client

local function _get_plugin_dir()
  local path = debug.getinfo(1).source:match("@(.*/)")
  return uv.fs_realpath(path .. '/../..')
end

-- Constructor
-- @param config Config @resolved configuration for this session
-- @param proxy_cmd string @command to launch the proxy
-- @param client_cmd string @command to launch the debugger
-- @return Client @new instance
function Client.new(config, proxy_cmd, client_cmd)
  log.debug({"function Client.new(", config, proxy_cmd, client_cmd, ")"})
  local self = setmetatable({}, Client)
  self.config = config
  log.info("termwin_command", config:get('termwin_command'))
  NvimGdb.vim.cmd(config:get('termwin_command'))
  self.win = vim.api.nvim_get_current_win()
  self.client_id = nil
  self.is_active = false
  -- Create a temporary unique directory for all the sockets.
  self.sock_dir = uv.fs_mkdtemp(uv.os_tmpdir() .. '/nvimgdb-sock-XXXXXX')

  -- Prepare the debugger command to run
  self.command = client_cmd
  if proxy_cmd ~= nil then
    self.proxy_addr = self.sock_dir .. '/port'
    self.command = _get_plugin_dir() .. "/lib/" .. proxy_cmd .. " -a " .. self.proxy_addr .. " -- " .. client_cmd
  end
  NvimGdb.vim.cmd "enew"
  self.client_buf = vim.api.nvim_get_current_buf()
  self.buf_hidden_auid = -1
  return self
end

-- Destructor
function Client:cleanup()
  log.debug({"function Client:cleanup()"})
  if vim.api.nvim_buf_is_valid(self.client_buf) and vim.fn.bufexists(self.client_buf) then
    self:_cleanup_buf_hidden()
    vim.api.nvim_buf_delete(self.client_buf, {force = true})
  end

  if self.proxy_addr then
    os.remove(self.proxy_addr)
  end
  assert(os.remove(self.sock_dir))
end

function Client:_cleanup_buf_hidden()
  log.debug({"function Client:_cleanup_buf_hidden()"})
  if self.buf_hidden_auid ~= -1 then
    vim.api.nvim_del_autocmd(self.buf_hidden_auid)
    self.buf_hidden_auid = -1
  end
end

-- Launch the debugger (when all the parsers are ready)
function Client:start()
  log.debug({"function Client:start()"})
  -- Open a terminal window with the debugger client command.
  -- Go to the yet-to-be terminal window
  vim.api.nvim_set_current_win(self.win)
  self.is_active = true

  local cur_tabpage = vim.api.nvim_get_current_tabpage()

  self.client_id = vim.fn.termopen(self.command, {
    on_stdout = function(--[[j]]_, lines, --[[name]]_)
      NvimGdb.parser_feed(cur_tabpage, lines)
    end,
    on_exit = function(--[[j]]_, code, --[[name]]_)
      if code == 0 then
        NvimGdb.vim.cmd("sil! bw!")
        NvimGdb.cleanup(cur_tabpage)
      end
    end
  })

  vim.bo.filetype = "nvimgdb"
  -- Allow detaching the terminal from its window
  vim.bo.bufhidden = "hide"
  -- Prevent the debugger buffer from being listed
  vim.bo.buflisted = false
  -- Finish the debugging session when the terminal is closed
  -- Left the remains of the code intentionally to remind that there is no need
  -- to close the debugger terminal automatically.
  --local cur_tabpage = vim.api.nvim_get_current_tabpage()
  --vim.cmd("au TermClose <buffer> lua NvimGdb.cleanup(" .. cur_tabpage .. ")")

  -- Check whether the terminal buffer should always be shown
  local sticky = self.config:get_or('sticky_dbg_buf', true)
  if sticky then
    self.buf_hidden_auid = vim.api.nvim_create_autocmd("BufHidden", {
      buffer = self.client_buf,
      callback = vim.schedule_wrap(function()
        self:_check_sticky()
      end),
    })
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = self.client_buf,
      callback = function()
        self:_cleanup_buf_hidden()
      end
    })
  end
end

-- Make the debugger window sticky. If closed accidentally,
-- resurrect it.
function Client:_check_sticky()
  log.debug({"function Client:_check_sticky()"})
  local prev_win = vim.api.nvim_get_current_win()
  NvimGdb.vim.cmd(self.config:get('termwin_command'))
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_valid(self.client_buf) then
    NvimGdb.vim.cmd('b ' .. self.client_buf)
  end
  vim.api.nvim_buf_delete(buf, {})
  self.win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(prev_win)
end

-- Interrupt running program by sending ^c.
function Client:interrupt()
  log.debug({"function Client:interrupt()"})
  vim.fn.chansend(self.client_id, "\x03")
end

-- Execute one command on the debugger interpreter.
-- @param data string @send a command to the debugger
function Client:send_line(data)
  log.debug({"function Client:send_line(", data, ")"})
  log.debug({"send_line", data})
  vim.fn.chansend(self.client_id, data .. "\n")
end

-- Get the client terminal buffer.
-- @return number @terminal buffer handle
function Client:get_buf()
  log.debug({"function Client:get_buf()"})
  return self.client_buf
end

-- Get the side-channel address.
-- @return string @file with proxy port
function Client:get_proxy_addr()
  log.debug({"function Client:get_proxy_addr()"})
  return self.proxy_addr
end

return Client
