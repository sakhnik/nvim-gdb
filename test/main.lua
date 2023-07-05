local thr = require'thread'
local runner = require("busted.runner")

arg = {"."}
local M = {}

local function report_result()
  vim.cmd("tabnew")
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
  local result = table.concat(_G.test_output, "")
  local lines = vim.split(result, "\n", {})
  vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
end

local function main()
  runner {standalone = false, output = 'output.lua'}
  report_result()
  M.thr:cleanup()
end

local function on_stuck()
  print("Thread stuck")
  report_result()
  M.thr:cleanup()
end

M.thr = thr.create(main, on_stuck)
