local thr = require'thread'
local runner = require'busted.runner'
local result = require'result'

arg = {"--verbose", "."}
local M = {}

local function report_result()
  local test_log = table.concat(result.test_output, "")
  local f = io.open('test.log', 'w')
  if f ~= nil then
    f:write(test_log)
    f:close()
  end
  if require'config'.exit_after_tests then
    os.exit(result.failures > 0 and 1 or 0)
  end
  vim.cmd("noswap tabnew test.log")
  vim.cmd([[
    syntax match DiagnosticOk /+/
    syntax match DiagnosticWarn /-/
    syntax match DiagnosticOk /\d\+ success[^ ]*/
    syntax match DiagnosticWarn /\d\+ failure[^ ]*/
    syntax match DiagnosticError /\d\+ error[^ ]*/
    syntax match DiagnosticInfo /\d\+ pending[^ ]*/
    syntax match Float /[0-9]\+\.[0-9]\+/
    syntax match DiagnosticWarn /Failure ->/
    syntax match DiagnosticError /Error ->/
  ]])
end

local function main()
  -- busted will try to end the process in case of failure, so disable os.exit() for now
  local exit_orig = os.exit
  os.exit = function() end
  local ok, err = pcall(runner, {standalone = false, output = 'output.lua'})
  if not ok then
    print(err)
  end
  os.exit = exit_orig
  report_result()
  M.thr:cleanup()
end

local function on_stuck()
  print("Thread stuck")
  report_result()
  M.thr:cleanup()
end

M.thr = thr.create(main, on_stuck)
