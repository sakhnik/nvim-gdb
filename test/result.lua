---@class Result
---@field test_output string[] @table of output chunks
---@field failures number @count of failures and errors
local R = {
  test_output = {},
  failures = 0,
}

return R
