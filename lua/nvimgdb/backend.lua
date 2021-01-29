-- vim: set et ts=2 sw=2:

-- Choose appropriate backend
local backend = {}

function backend.choose(name)
  if name == "gdb" then
    return require "nvimgdb.backend.gdb".new()
  elseif name == "lldb" then
    return require "nvimgdb.backend.lldb".new()
  elseif name == "pdb" then
    return require "nvimgdb.backend.pdb".new()
  elseif name == "bashdb" then
    return require "nvimgdb.backend.bashdb".new()
  end
end

return backend
