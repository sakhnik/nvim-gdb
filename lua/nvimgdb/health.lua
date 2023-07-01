local M = {}

local health = vim.health
local utils = require'nvimgdb.utils'

-- "report_" prefix has been deprecated, use the recommended replacements if they exist.
local _start = health.start or health.report_start
local _ok = health.ok or health.report_ok
local _warn = health.warn or health.report_warn
local _error = health.error or health.report_error
local _info = health.info or health.report_info

local results = {}

local function execute_command(job_name, cmd)
  local on_data = function(_, data, name)
    local res = results[job_name]
    res[name] = data
    if res == nil then
      res = {}
      results[job_name] = res
    end
  end

  local opts = {
    stderr_buffered = true,
    stdout_buffered = true,
    on_stdout = on_data,
    on_stderr = on_data,
  }

  results[job_name] = {}
  local success, job_id = pcall(vim.fn.jobstart, cmd, opts)
  if not success then
    results[job_name].error = '`' .. cmd[1] .. '` is not executable'
    return -1
  end
  return job_id
end

local function get_version(output)
  return vim.split(output, "\n")[1]
end

local function check_result(name)
  local result = results[name]
  if result.error ~= nil then
    _error(result.error)
    return false
  end
  return true
end

local function check_version(name, message, output)
  if not check_result(name) then
    return
  end
  if message == "" then
    _ok(get_version(output))
  else
    _ok(message .. " " .. get_version(output))
  end
end

M.check = function()

  local commands = {
    gdb = {"gdb", "--version"},
    gdb_py = {"gdb", "--batch", "-ex", "python import sys; print(sys.version)"},
    lldb = {"lldb", "--version"},
    lldb_py = {"lldb", "--batch", "-o", "script import lldb, sys; print(sys.version)", "-o", "quit"},
    python = {"python", "--version"},
  }
  if not utils.is_windows then
    commands.rr = {"rr", "--version"}
    commands.bashdb = {"bashdb", "--version"}
  else
    commands.winpty = {"python", "-c", "import winpty; print(winpty.__version__)"}
  end

  local job_ids = {}
  for name, cmd in pairs(commands) do
      local job_id = execute_command(name, cmd)
      if job_id > 0 then
        table.insert(job_ids, job_id)
      end
  end
  vim.fn.jobwait(job_ids, -1)
  print(vim.print(results))

  --_start "Prerequisites"
  --local has_python = check_cmd("env python3", "--version")
  _start "GDB backend"
  check_version("gdb", "", results.gdb.stdout[1])
  check_version("gdb_py", "GNU gdb Python", results.gdb_py.stdout[1])
  _start "LLDB backend"
  check_version("lldb", "", results.lldb.stdout[1])
  check_version("lldb_py", "lldb Python", results.lldb_py.stdout[2])
  if results.rr ~= nil then
    _start "RR executable (requires gdb backend)"
    check_version("rr", "", results.rr.stdout[1])
  end
  _start "PDB backend"
  check_version("python", "", results.python.stdout[1])
  if utils.is_windows then
    check_version("winpty", "pywinpty", results.winpty.stdout[1])
  end
  if results.bashdb ~= nil then
    _start "BashDB backend"
    check_version("bashdb", "", results.bashdb.stderr[1])
    check_version("python", "", results.python.stdout[1])
  end
end

return M
