local M = {}

local health = vim.health
local fn = vim.fn

-- "report_" prefix has been deprecated, use the recommended replacements if they exist.
local _start = health.start or health.report_start
local _ok = health.ok or health.report_ok
local _warn = health.warn or health.report_warn
local _error = health.error or health.report_error

local function check_cmd(cmd)
  if fn.executable(cmd) == 0 then
    _warn("`" .. cmd .. "` executable not found")
  else
    local handle = io.popen(cmd .. " --version 2>&1")
    if handle == nil then
      _error("Can't run `" .. cmd .. "`")
    else
      local result = handle:read "*a"
      handle:close()
      local version = vim.split(result, "\n")[1]
      _ok("`" .. cmd .. "` found " .. version)
    end
  end
end

M.check = function()
  _start "Prerequisites"
  check_cmd("python")
  _start "GDB backend"
  check_cmd("gdb")
  _start "LLDB backend"
  check_cmd("lldb")
  _start "PDB backend"
  _start "BashDB backend"
  check_cmd("bashdb")
end

return M
