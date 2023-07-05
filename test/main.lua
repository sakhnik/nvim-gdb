local thr = require'thread'
local runner = require("busted.runner")

arg = {"."}
local M = {}

local function report_result()
  vim.cmd("tabnew")
  local result = {}
  for _, res in ipairs(_G.test_result) do
    local status = res[3]
    local name = res[2].name .. '::' .. res[1].name
    local duration = string.format("%.3f", res[1].duration)
    table.insert(result, table.concat({status, duration, name}, '\t'))
    if status == "failure" then
      for _, line in ipairs(vim.split(res[1].trace.traceback, "\n")) do
        table.insert(result, line)
      end
    end
  end
  vim.api.nvim_buf_set_lines(0, 0, 0, false, result)
end

local function main()
  runner({standalone = false, output = 'output.lua'})
  report_result()
  M.thr:cleanup()
end

local function on_stuck()
  print("Thread stuck")
  report_result()
  M.thr:cleanup()
end

M.thr = thr.create(main, on_stuck)
