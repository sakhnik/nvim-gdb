local uv = vim.loop
local log = require'nvimgdb.log'

local CMake = {}

---Select executables when editing command line
---@return string user decision
function CMake.select_executable()
  log.debug({"CMake.select_executable"})
  -- Identify the prefix of the required executable path: scan to the left until the nearest space
  local curcmd = vim.fn.getcmdline()
  local pref_end = vim.fn.getcmdpos() - 1
  local prefix = curcmd:sub(1, pref_end):match('.*%s(.*)')
  log.debug({"prefix", prefix})
  local msg = {"Select executable:"}
  local execs = CMake.get_executables(prefix)
  for i, exe in ipairs(execs) do
    msg[#msg+1] = i .. '. ' .. exe
  end
  local idx = vim.fn.inputlist(msg)
  if idx <= 0 or idx > #execs then
    return curcmd
  end
  local selection = execs[idx]
  vim.fn.setcmdpos(pref_end - #prefix + 1 + #selection)
  return curcmd:sub(1, pref_end - #prefix) .. selection .. curcmd:sub(pref_end + 1)
end

---Find executables with the given path prefix
---@param prefix string path prefix
---@return string[] paths of found executables
function CMake.find_executables(prefix)
  log.debug({'CMake.find_executables', prefix = prefix})
  local function is_executable(file_path)
    local stat = uv.fs_stat(file_path)
    if stat and stat.type == 'file' then
      return bit.band(stat.mode, 73) > 0   -- 73 == 0111
    end
    return false
  end
  if #prefix == 0 then
    prefix = './'
  end
  local prefix_path = uv.fs_realpath(prefix)
  local prefix_dir = vim.fs.dirname(prefix_path)
  if prefix:sub(#prefix):match('[/\\]') then
    prefix_path = prefix_path .. prefix:sub(#prefix)
  end
  local escaped_prefix_path = string.gsub(prefix_path, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")

  local progress_path = ''
  local found_executables = vim.fs.find(function(name, path)
    if path:find('[/\\]CMakeFiles[/\\]') then
      return false
    end
    if progress_path ~= path then
      print("Scanning " .. path)
      progress_path = path
    end
    local file_path = path .. '/' .. name
    if not file_path:find(escaped_prefix_path) then
      return false
    end
    if not is_executable(file_path) then
      return false
    end
    local mime = vim.fn.system({'file', '--brief', '--mime-encoding', file_path})
    if not mime:match('binary') then
      return false
    end
    return true
  end, {limit = 1000, type = 'file', path = prefix_dir})

  for i, e in ipairs(found_executables) do
    found_executables[i] = e:gsub(escaped_prefix_path, prefix)
  end
  return found_executables
end

---Get paths of executables from both cmake and directory scanning
---@param prefix string path prefix
---@return string[] list of found executables
function CMake.get_executables(prefix)
  log.debug({'CMake.get_executables', prefix = prefix})
  -- Use CMake
  local execs = vim.fn["guess_executable_cmake#ExecutablesOfBuffer"](prefix)
  local found = CMake.find_executables(prefix)
  for _, exe in ipairs(found) do
    execs[#execs+1] = exe
  end
  return execs
end

-- targets structure is:
-- [{artifacts:[...], 
--   link: {commandFragments: [{fragment:"<file_name>", ...}, ...], ...}, 
--   sources: [{path:"<file_name>", ...}...]
--  }, ...]
-- Library files (*.a, *.so) are in commandFragments and source files (*.c,
-- *.cpp) are in sources
---Filter targets keeping those that reference the given file_name
---@param targets table
---@param file_name string
---@return table
function CMake.targets_that_use_files(targets, file_name)
  if string.find(file_name, '%.cp?p?$') then
    local ret = {}
    for _, target in ipairs(targets) do
      for _, source in ipairs(target.sources) do
        if vim.fn.match(source.path, file_name) >= 0 then
          ret[#ret+1] = target
          break
        end
      end
    end
    return ret
  end
  if string.match(file_name, '%.so$') or string.match(file_name, '%.a$') then
    local basename = file_name:find('([^/\\]+)$')
    local ret = {}
    for _, target in ipairs(targets) do
      for _, command_fragment in ipairs(target.link.commandFragments) do
        if vim.fn.match(command_fragment.fragment, basename) >= 0 then
          ret[#ret+1] = target
          break
        end
      end
    end
    return ret
  end
  return {}
end

return CMake
