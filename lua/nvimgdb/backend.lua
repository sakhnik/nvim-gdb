-- vim: set et ts=2 sw=2:

-- Choose appropriate backend
backend = {}

function backend.choose(name)
  if name == "gdb" then
    return require "nvimgdb.backend.gdb"
  elseif name == "lldb" then
    return require "nvimgdb.backend.lldb"
  elseif name == "pdb" then
    return require "nvimgdb.backend.pdb"
  elseif name == "bashdb" then
    return require "nvimgdb.backend.bashdb"
  end
end

return backend
