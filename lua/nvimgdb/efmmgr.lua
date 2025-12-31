-- Manager for the 'errorformat'.
-- vim: set et ts=2 sw=2:

---@class EfmMgr errorformat manager
---@field private prev_o_efm string previous 'errorformat' value
local efmmgr = {
  prev_o_efm = '',
  prev_bo_efm = '',
}

---Add 'efm' for some backend.
---@param formats string[]
function efmmgr.setup(formats)
  efmmgr.prev_o_efm = vim.o.efm
  efmmgr.prev_bo_efm = vim.bo.efm
  vim.o.efm = ''
  for _, f in ipairs(formats) do
    vim.api.nvim_command("set efm+=" .. f)
  end
end

---Remove 'efm' entries for some backend.
function efmmgr.teardown()
  vim.o.efmmgr = efmmgr.prev_o_efm
  vim.bo.efmmgr = efmmgr.prev_bo_efm
end

return efmmgr
