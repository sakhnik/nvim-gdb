local M = {}

local health = vim.health
local utils = require'nvimgdb.utils'

-- "report_" prefix has been deprecated, use the recommended replacements if they exist.
local _start = health.start or health.report_start
local _ok = health.ok or health.report_ok
local _warn = health.warn or health.report_warn
local _error = health.error or health.report_error
local _info = health.info or health.report_info

local Tests = {}
Tests.__index = Tests


function Tests:execute_command(job_name, cmd)
  local on_data = function(_, data, name)
    local res = self.results[job_name]
    res[name] = data
    if res == nil then
      res = {}
      self.results[job_name] = res
    end
  end

  local opts = {
    stderr_buffered = true,
    stdout_buffered = true,
    on_stdout = on_data,
    on_stderr = on_data,
  }

  self.results[job_name] = {}
  local success, job_id = pcall(vim.fn.jobstart, cmd, opts)
  if not success then
    self.results[job_name].error = '`' .. cmd[1] .. '` is not executable'
    return -1
  end
  return job_id
end

local function get_version(output)
  return vim.split(output, "[\r\n]")[1]
end

function Tests:get_result(name)
  return self.results[name]
end

local function stdout_getter(line)
  return function(result)
    if result.stdout == nil then
      return nil
    end
    return result.stdout[line]
  end
end

local function stderr_getter(line)
  return function(result)
    if result.stderr == nil then
      return nil
    end
    return result.stderr[line]
  end
end

local function get_message(prefix, message)
  if prefix ~= "" then
    return prefix .. " " .. message
  end
  return message
end

function Tests:check_version(name, message, getter)
  local result = self.results[name]
  if result.error ~= nil then
    _error(get_message(message, result.error))
    return false
  end

  local output = getter(result)
  if output == nil then
    _error(get_message(message, "failed"))
    return false
  end

  _ok(get_message(message, get_version(output)))
  return true
end

function Tests.execute_commands(commands)
  local self = setmetatable({}, Tests)
  self.results = {}
  local job_ids = {}
  for name, cmd in pairs(commands) do
    local job_id = self:execute_command(name, cmd)
      if job_id > 0 then
        table.insert(job_ids, job_id)
      end
  end
  vim.fn.jobwait(job_ids, -1)
  return self
end

M.check = function()

  local commands = {
    gdb = {"gdb", "--version"},
    gdb_py = {"gdb", "--batch", "-ex", "python import sys; print(sys.version)"},
    lldb = {"lldb", "--version"},
    lldb_py = {"lldb", "--batch", "-o", "script import lldb, sys; print(sys.version)", "-o", "quit"},
    python = {"python", "--version"},
    pytest = {"python", "-c", "import pytest; print(f'{pytest.__name__} {pytest.__version__}')"},
    pynvim = {"python", "-c", "import pynvim; v=pynvim.VERSION; print(f'{pynvim.__name__} {v.major}.{v.minor}.{v.patch}{v.prerelease}')"},
  }
  if utils.is_linux then
    commands.rr = {"rr", "--version"}
  end
  if not utils.is_windows then
    commands.bashdb = {"bashdb", "--version"}
  else
    commands.winpty = {"python", "-c", "import winpty; print(f'{winpty.__name__} {winpty.__version__}')"}
  end

  local tests = Tests.execute_commands(commands)
  local results = tests.results

  _start "GDB backend"
  local has_gdb = tests:check_version("gdb", "", stdout_getter(1))
  if has_gdb then
    tests:check_version("gdb_py", "GNU gdb Python", stdout_getter(1))
  end

  _start "LLDB backend"
  local has_lldb = tests:check_version("lldb", "", stdout_getter(1))
  if has_lldb then
    tests:check_version("lldb_py", "lldb Python", stdout_getter(2))
  end

  if results.rr ~= nil then
    _start "RR executable"
    local has_rr = tests:check_version("rr", "", stdout_getter(1))
    if has_rr then
      tests:check_version("gdb", "", stdout_getter(1))
    end
  end

  _start "PDB backend"
  local has_python = tests:check_version("python", "", stdout_getter(1))
  if utils.is_windows and has_python then
    tests:check_version("winpty", "pywinpty", stdout_getter(1))
  end
  if results.bashdb ~= nil then
    _start "BashDB backend"
    local has_bashdb = tests:check_version("bashdb", "", stderr_getter(1))
    if has_bashdb then
      tests:check_version("python", "", stdout_getter(1))
    end
  end
  _start "Test suite"
  tests:check_version("python", "", stdout_getter(1))
  tests:check_version("pytest", "", stdout_getter(1))
  tests:check_version("pynvim", "", stdout_getter(1))
end

return M
