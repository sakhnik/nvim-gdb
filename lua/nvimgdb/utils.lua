local uv = vim.loop

local Utils = {}
Utils.__index = Utils

local function get_plugin_dir()
  local path = debug.getinfo(1).source:match("@(.*/)")
  return uv.fs_realpath(path .. '/../..')
end

-- Full path to the plugin directory
Utils.plugin_dir = get_plugin_dir()

-- @true if in Windows, false otherwise
Utils.is_windows = vim.loop.os_uname().sysname:find('Windows') ~= nil

local function get_path_separator()
  local sep = '/'
  if Utils.is_windows then
    sep = '\\'
  end
  return sep
end

Utils.fs_separator = get_path_separator()

-- Join path components
-- @return string @path with components separating according to the platform conventions
Utils.path_join = function(path, ...)
  for _, name in ipairs({...}) do
    path = path .. Utils.fs_separator .. name
  end
  return path
end

-- Get full path of a file in the plugin directory
-- @return string @full path to the file given its path components
Utils.get_plugin_file_path = function(...)
  return Utils.path_join(Utils.plugin_dir, ...)
end

return Utils
