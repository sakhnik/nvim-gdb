-- Logger taken from language client plugin.

local log = {}

-- FIXME: DOC
-- Should be exposed in the vim docs.
--
-- Log level dictionary with reverse lookup as well.
--
-- Can be used to lookup the number from the name or the name from the number.
-- Levels by name: 'trace', 'debug', 'info', 'warn', 'error'
-- Level numbers begin with 'trace' at 0
log.levels = {
  TRACE = 0;
  DEBUG = 1;
  INFO  = 2;
  WARN  = 3;
  ERROR = 4;
  CRIT = 5;
}

-- Default log level.
local current_log_level = log.levels.CRIT
if vim.env.CI ~= nil then
  current_log_level = log.levels.DEBUG
end

local log_date_format = "%F %H:%M:%S"

do
  local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
  --@private
  local function path_join(...)
    return table.concat(vim.tbl_flatten{...}, path_sep)
  end
  --local logfilename = path_join(vim.fn.stdpath('cache'), 'lsp.log')
  local logfilename = 'nvimgdb2.log'

  --- Returns the log filename.
  --@returns (string) log filename
  function log.get_filename()
    return logfilename
  end

  --vim.fn.mkdir(vim.fn.stdpath('cache'), "p")
  local logfile = nil
  local get_logfile = function()
    if logfile == nil then
      logfile = assert(io.open(logfilename, "a+"))
    end
    return logfile
  end

  for level, levelnr in pairs(log.levels) do
    -- Also export the log level on the root object.
    log[level] = levelnr
    -- FIXME: DOC
    -- Should be exposed in the vim docs.
    --
    -- Set the lowercase name as the main use function.
    -- If called without arguments, it will check whether the log level is
    -- greater than or equal to this one. When called with arguments, it will
    -- log at that level (if applicable, it is checked either way).
    --
    -- Recommended usage:
    -- ```
    -- local _ = log.warn() and log.warn("123")
    -- ```
    --
    -- This way you can avoid string allocations if the log level isn't high enough.
    log[level:lower()] = function(...)
      local argc = select("#", ...)
      if levelnr < current_log_level then return false end
      if argc == 0 then return true end
      local info = debug.getinfo(2, "Sl")
      local fileinfo = string.format("%s:%s", info.short_src, info.currentline)
      local parts = { table.concat({os.date(log_date_format), " [", level, "] ", fileinfo, ": "}, "") }
      for i = 1, argc do
        local arg = select(i, ...)
        if arg == nil then
          table.insert(parts, "nil")
        else
          table.insert(parts, vim.inspect(arg, {newline=''}))
        end
      end
      get_logfile():write(table.concat(parts, '\t'), "\n")
      logfile:flush()
    end
  end
end

-- This is put here on purpose after the loop above so that it doesn't
-- interfere with iterating the levels
vim.tbl_add_reverse_lookup(log.levels)

--- Sets the current log level.
--@param level (string or number) One of `vim.lsp.log.levels`
function log.set_level(level)
  if type(level) == 'string' then
    current_log_level = assert(log.levels[level:upper()], string.format("Invalid log level: %q", level))
  else
    assert(type(level) == 'number', "level must be a number or string")
    assert(log.levels[level], string.format("Invalid log level: %d", level))
    current_log_level = level
  end
end

--- Checks whether the level is sufficient for logging.
--@param level number log level
--@returns (bool) true if would log, false if not
function log.should_log(level)
  return level >= current_log_level
end

return log
-- vim:sw=2 ts=2 et
