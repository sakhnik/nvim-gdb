local log = {}

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
log.current_log_level = (vim.env.CI == nil) and log.levels.CRIT or log.levels.DEBUG

local logfilename = 'nvimgdb.log'
local logfile = nil

--- Returns the log filename.
---@return string log filename
function log.get_filename()
  return logfilename
end

local get_logfile = function()
  if logfile == nil then
    logfile = assert(io.open(logfilename, "a+"))
  end
  return logfile
end

---Set log file name
---@param filename string new log filename
function log.set_filename(filename)
  if filename ~= logfilename then
    logfilename = filename
    if logfile ~= nil then
      logfile:close()
      logfile = nil
    end
  end
end

local log_date_format = "%F %H:%M:%S"

do
  local function get_timestamp()
    local sec, usec = vim.loop.gettimeofday()
    return os.date(log_date_format, sec) .. "," .. string.format("%03d", math.floor(usec / 1000))
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
      if levelnr < log.current_log_level then return false end
      if argc == 0 then return true end
      local info = debug.getinfo(2, "Sl")
      local src = info.short_src
      -- Chop off the long path prefix, just keep everything relative to lua/ or lib/
      local suffix = src:match("l[ui][ab][/\\].+")
      if suffix ~= nil then
        src = suffix
      end

      local fileinfo = string.format("%s:%s", src, info.currentline)
      local parts = { table.concat({get_timestamp(), " [", level, "] ", fileinfo, ": "}, "") }
      for i = 1, argc do
        local arg = select(i, ...)
        if arg == nil then
          table.insert(parts, "nil")
        else
          table.insert(parts, vim.inspect(arg, {newline=''}))
        end
      end
      get_logfile():write(table.concat(parts, '\t'), "\n")
      get_logfile():flush()
    end
  end
end

-- This is put here on purpose after the loop above so that it doesn't
-- interfere with iterating the levels
-- vim.tbl_add_reverse_lookup(log.levels)
log.levels[0] = "TRACE"
log.levels[1] = "DEBUG"
log.levels[2] = "INFO"
log.levels[3] = "WARN"
log.levels[4] = "ERROR"
log.levels[5] = "CRIT"

--- Sets the current log level.
--@param level string|number One of `vim.lsp.log.levels`
function log.set_level(level)
  if type(level) == 'string' then
    log.current_log_level = assert(log.levels[level:upper()], string.format("Invalid log level: %q", level))
  else
    assert(type(level) == 'number', "level must be a number or string")
    assert(log.levels[level], string.format("Invalid log level: %d", level))
    log.current_log_level = level
  end
end

--- Checks whether the level is sufficient for logging.
--@param level number log level
--@returns (bool) true if would log, false if not
function log.should_log(level)
  return level >= log.current_log_level
end

return log
-- vim:sw=2 ts=2 et
