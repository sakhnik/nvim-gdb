-- Manager for the 'errorformat'.
-- vim: set et ts=2 sw=2:

local counters = {}  -- {efm: count}
local efmmgr = {}

-- Destructor
function efmmgr.cleanup()
  for f, _ in pairs(counters) do
    vim.cmd("set efm-=" .. f)
  end
end

-- Add 'efm' for some backend.
function efmmgr.setup(formats)
  for _, f in ipairs(formats) do
    c = counters[f]
    if c == nil then
      c = 0
      vim.cmd("set efm+=" .. f)
    end
    counters[f] = c + 1
  end
end

-- Remove 'efm' entries for some backend.
function efmmgr.teardown(formats)
  for _, f in ipairs(formats) do
    c = counters[f] - 1
    if c <= 0 then
      vim.cmd("set efm-=" .. f)
      c = nil
    end
    counters[f] = c
  end
end

return efmmgr
