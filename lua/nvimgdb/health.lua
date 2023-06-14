local M = {}

local health = vim.health
local fn = vim.fn

-- "report_" prefix has been deprecated, use the recommended replacements if they exist.
local _start = health.start or health.report_start
local _ok = health.ok or health.report_ok
local _warn = health.warn or health.report_warn
local _error = health.error or health.report_error
local _info = health.info or health.report_info

local function check_output(msg, cmd, filter)
  local handle = io.popen(cmd)
  if handle == nil then
    _error("Can't run `" .. cmd .. "`")
    return false
  end
  local result = handle:read "*a"
  handle:close()
  _ok(msg .. " " .. filter(result))
  return true
end

local function get_whole_output(output)
  return output
end

local function get_version(output)
  return vim.split(output, "\n")[1]
end

local function check_cmd(cmd, args)
  return check_output("`" .. cmd .. "` found ", cmd .. ' ' .. args, get_version)
end

local function check_executable(exe, args)
  if fn.executable(exe) == 0 then
    _warn("`" .. exe .. "` executable not found")
    return false
  end
  return check_cmd(exe,  args)
end

M.check = function()
  _start "Prerequisites"
  local has_python = check_cmd("env python3", "--version")
  _start "GDB backend"
  check_executable("gdb", "--version")
  check_output("GDB Python version is ", "gdb --batch -ex 'python import sys; print(sys.version)'", get_version)
  _start "LLDB backend"
  local has_lldb = check_executable("lldb", "--version")
  _start "RR backend"
  if has_lldb and not has_python then
    _info "Python3 isn't required for LLDB"
  end
  check_executable("rr", "--version")
  _start "PDB backend"
  if has_python then _ok("`pdb` shipped with Python3") else _error("`pdb` no Python3") end
  _start "BashDB backend"
  check_executable("bashdb", "--version 2>&1")
end

return M
