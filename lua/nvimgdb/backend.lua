-- vim: set et ts=2 sw=2:

local backend = {}

-- Choose appropriate backend
-- @param name string @backend name
-- @return Backend @new instance
function backend.choose(name)
  if name == "gdb" then
    return require "nvimgdb.backend.gdb".new()
  elseif name == "lldb" then
    return require "nvimgdb.backend.lldb".new()
  elseif name == "pdb" then
    return require "nvimgdb.backend.pdb".new()
  elseif name == "bashdb" then
    return require "nvimgdb.backend.bashdb".new()
  else
    return assert(nil, "Not supported")
  end
end

return backend
