local uv = vim.loop

local CMake = {}

---Select executables when editing command line
---@return string user decision
function CMake.select_executable()
  local curcmd = vim.fn.getcmdline()
  local pos = vim.fn.getcmdpos()
  local lead = ''
  while pos > 0 and curcmd:sub(pos, 1) ~= ' ' do
    local ch = curcmd:sub(pos + 1, 1)
    if ch == ' ' then
      break
    end
    lead = ch .. lead
    pos = pos - 1
  end
  local msg = {"Select executable:"}
  local execs = CMake.get_executables(lead)
  for i, exe in ipairs(execs) do
    msg[#msg+1] = i .. '. ' .. exe
  end
  local idx = vim.fn.inputlist(msg)
  if idx <= 0 or idx > #execs then
    return ''
  end
  return execs[idx]
end

---Find executables with the given path prefix
---@param lead string path prefix
---@return string[] paths of found executables
function CMake.find_executables(lead)
  local function is_executable(file_path)
    local stat = uv.fs_stat(file_path)
    if stat and stat.type == 'file' then
      return bit.band(stat.mode, 73) > 0   -- 73 == 0111
    end
    return false
  end
  if #lead == 0 then
    lead = './'
  end
  local lead_path = uv.fs_realpath(lead)
  local lead_dir = vim.fs.dirname(lead_path)
  if lead:sub(#lead):match('[/\\]') then
    lead_path = lead_path .. lead:sub(#lead)
  end
  local escaped_lead_path = string.gsub(lead_path, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")

  local found_executables = vim.fs.find(function(name, path)
    if path:find('CMakeFiles') then
      return false
    end
    local file_path = path .. '/' .. name
    if not file_path:find(escaped_lead_path) then
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
  end, {limit = 1000, type = 'file', path = lead_dir})

  for i, e in ipairs(found_executables) do
    found_executables[i] = e:gsub(escaped_lead_path, lead)
  end
  return found_executables
end

---Get paths of executables from both cmake and directory scanning
---@param lead string path prefix
---@return string[] list of found executables
function CMake.get_executables(lead)
  -- Use CMake
  local execs = vim.fn["guess_executable_cmake#ExecutablesOfBuffer"](lead)
  local found = CMake.find_executables(lead)
  for _, exe in ipairs(found) do
    execs[#execs+1] = exe
  end
  return execs
end

return CMake
