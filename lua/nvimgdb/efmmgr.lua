-- Manager for the 'errorformat'.
-- vim: set et ts=2 sw=2:

-- @class EfmMgr @errorformat manager
-- @field private counters table<string, number> @specific errorformat counter
local efmmgr = {
  counters = {}
}

-- Destructor
function efmmgr.cleanup()
  for f, _ in pairs(efmmgr.counters) do
    vim.cmd("set efm-=" .. f)
  end
end

-- Add 'efm' for some backend.
-- @param formats string[]
function efmmgr.setup(formats)
  for _, f in ipairs(formats) do
    local c = efmmgr.counters[f]
    if c == nil then
      c = 0
      vim.cmd("set efm+=" .. f)
    end
    efmmgr.counters[f] = c + 1
  end
end

-- Remove 'efm' entries for some backend.
-- @param formats string[]
function efmmgr.teardown(formats)
  for _, f in ipairs(formats) do
    local c = efmmgr.counters[f] - 1
    if c <= 0 then
      vim.cmd("set efm-=" .. f)
      c = nil
    end
    efmmgr.counters[f] = c
  end
end

return efmmgr
