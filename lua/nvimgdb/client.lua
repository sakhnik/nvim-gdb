-- The class to maintain connection to the debugger client.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'
local uv = vim.loop
local utils = require'nvimgdb.utils'

---@class Client spawned debugger manager
---@field private config Config resolved configuration
---@field public win number terminal window handler
---@field private client_id number terminal job handler
---@field private is_active boolean true if the debugger has been launched
---@field private has_interacted boolean true if the debugger was interactive
---@field private tmp_dir string temporary directory for the proxy address
---@field private proxy_addr string path to the file with proxy port
---@field private command string[] complete command to launch the debugger (including proxy)
---@field private client_buf number terminal buffer handler
---@field private buf_hidden_auid number autocmd id of the BufHidden handler
local Client = {}
Client.__index = Client

---Constructor
---@param config Config resolved configuration for this session
---@param backend Backend debugger backend
---@param client_cmd string[] command to launch the debugger
---@return Client new instance
function Client.new(config, backend, client_cmd)
  log.debug({"Client.new", client_cmd = client_cmd})
  local self = setmetatable({}, Client)
  self.config = config
  log.info("termwin_command", config:get('termwin_command'))
  vim.api.nvim_command(config:get('termwin_command'))
  self.win = vim.api.nvim_get_current_win()
  self.client_id = nil
  self.is_active = false
  self.has_interacted = false
  -- Create a temporary unique directory for all the sockets.
  self.tmp_dir = uv.fs_mkdtemp(uv.os_tmpdir() .. '/nvimgdb-XXXXXX')
  self.proxy_addr = utils.path_join(self.tmp_dir, 'port')

  -- Prepare the debugger command to run
  self.command = backend.get_launch_cmd(client_cmd, self.tmp_dir, self.proxy_addr)
  log.info({"Debugger command", self.command})

  vim.api.nvim_command "enew"
  self.client_buf = vim.api.nvim_get_current_buf()
  self.buf_hidden_auid = -1
  return self
end

---Destructor
function Client:cleanup()
  log.debug({"Client:cleanup"})
  if vim.api.nvim_buf_is_valid(self.client_buf) and vim.fn.bufexists(self.client_buf) then
    self:_cleanup_buf_hidden()
    vim.api.nvim_buf_delete(self.client_buf, {force = true})
  end

  if self.proxy_addr then
    os.remove(self.proxy_addr)
  end
  vim.fn.delete(self.tmp_dir, "rf")
end

---Get client buffer
---@return number client buffer
function Client:get_client_buf()
  return self.client_buf
end

function Client:_cleanup_buf_hidden()
  log.debug({"Client:_cleanup_buf_hidden"})
  if self.buf_hidden_auid ~= -1 then
    vim.api.nvim_del_autocmd(self.buf_hidden_auid)
    self.buf_hidden_auid = -1
  end
end

---Launch the debugger (when all the parsers are ready)
function Client:start()
  log.debug({"Client:start"})
  -- Open a terminal window with the debugger client command.
  -- Go to the yet-to-be terminal window
  vim.api.nvim_set_current_win(self.win)
  self.is_active = true

  local cur_tabpage = vim.api.nvim_get_current_tabpage()
  local app = assert(NvimGdb.i(cur_tabpage))

  self.client_id = vim.fn.termopen(self.command, {
    on_stdout = function(--[[j]]_, lines, --[[name]]_)
      if NvimGdb ~= nil then
        app.parser:feed(lines)
      end
    end,
    on_exit = function(--[[j]]_, code, --[[name]]_)
      if self.has_interacted and code == 0 then
        local cur_app = NvimGdb.i(cur_tabpage)
        -- Deal with the race, check that this client is still working in the same tabpage
        if app == cur_app then
          vim.api.nvim_command("sil! bw!")
          NvimGdb.cleanup(cur_tabpage)
        end
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

---Make the debugger window sticky. If closed accidentally,
---resurrect it.
function Client:_check_sticky()
  log.debug({"Client:_check_sticky"})
  local prev_win = vim.api.nvim_get_current_win()
  vim.api.nvim_command(self.config:get('termwin_command'))
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_valid(self.client_buf) then
    vim.api.nvim_command('b ' .. self.client_buf)
  end
  vim.api.nvim_buf_delete(buf, {})
  self.win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(prev_win)
end

---Interrupt running program by sending ^c.
function Client:interrupt()
  log.debug({"Client:interrupt"})
  vim.fn.chansend(self.client_id, "\x03")
end

---Execute one command on the debugger interpreter.
---@param data string send a command to the debugger
function Client:send_line(data)
  log.info({"Client:send_line", data = data})
  local cr = "\n"
  if utils.is_windows then
    cr = "\r"
  end
  vim.fn.chansend(self.client_id, data .. cr)
end

---Get the client terminal buffer.
---@return number terminal buffer handle
function Client:get_buf()
  log.debug({"Client:get_buf"})
  return self.client_buf
end

---Get the side-channel address.
---@return string file with proxy port
function Client:get_proxy_addr()
  log.debug({"Client:get_proxy_addr"})
  return self.proxy_addr
end

---Remember this debugger reached the interactive state
---This means we can close the terminal whenever the debugger quits
---Otherwise, keep the terminal to show the output to the user.
function Client:mark_has_interacted()
  self.has_interacted = true
end

return Client
