-- Common FSM implementation for the integrated backends.
-- vim: set et ts=2 sw=2:

local log = require'nvimgdb.log'

-- @class ParserImpl @base parser implementation
-- @field private actions ParserActions @parser callbacks
local C = {}
C.__index = C

-- Constructor
-- @param actions ParserActions @parser callbacks
-- @return ParserImpl
function C.new(actions)
  local self = setmetatable({}, C)
  self:_init(actions)
  return self
end

-- Initialization
-- @param actions ParserActions @parser callbacks
function C:_init(actions)
  self.actions = actions
  -- The running state
  self.running = {}
  -- The paused state [(matcher, matchingFunc)]
  self.paused = {}
  -- Current state (either self.running or self.paused)
  self.state = self.paused
  self.buffer = '\n'
  -- Monotonously increasing processed byte counter
  self.byte_count = 1
  -- Ordered byte counters to ensure parsing in the right order
  self.parsing_progress = {}
end

-- Add a new transition for a given state.
function C.add_trans(state, matcher, func)
  state[#state + 1] = {matcher, func}
end

-- Test whether the FSM is in the paused state.
function C:is_paused()
  return self.state == self.paused
end

-- Test whether the FSM is in the running state.
function C:is_running()
  return self.state == self.running
end

function C:_get_state_name()
  if self.state == self.running then
    return "running"
  end
  if self.state == self.paused then
    return "paused"
  end
  return tostring(self.state)
end

function C:_paused_continue(_)
  log.info("_paused_continue")
  self.actions:continue_program()
  return self.running
end

function C:_paused_jump(fname, line)
  log.info("_paused_jump " .. fname .. ":" .. line)
  self.actions:jump_to_source(fname, tonumber(line))
  return self.paused
end

function C:_paused(_)
  log.info('_paused')
  return self.paused
end

function C:_query_b(_)
  log.info('_query_b')
  self.actions:query_breakpoints()
  return self.paused
end

-- Process a line of the debugger output through the FSM.
-- It may be hard to guess when the backend started waiting for input,
-- therefore parsing should be done asynchronously after a bit of delay.
function C:feed(lines)
  for _, line in ipairs(lines) do
    log.debug(line)
    if line == nil or line == '' then
      line = '\n'
    else
      -- Filter out control sequences
      line = line:gsub('\x1B[@-_][0-?]*[ -/]*[@-~]', '')
    end
    self.buffer = self.buffer .. line
    self.byte_count = self.byte_count + #line
  end
  self.parsing_progress[#self.parsing_progress + 1] = self.byte_count
  self:_delay_parsing(50, self.byte_count)
end

function C:_delay_parsing(delay_ms, byte_count)
  local timer = vim.loop.new_timer()
  timer:start(delay_ms, 0, vim.schedule_wrap(function()
    self:delay_elapsed(byte_count)
  end))
end

function C:_search(ignore_tail_bytes)
  if #self.buffer <= ignore_tail_bytes then
    return false
  end
  -- If there is a matcher matching the line, call its handler.
  for _, mf in ipairs(self.state) do
    local matcher, func = unpack(mf)
    local b, e, m1, m2 = self.buffer:find(matcher)
    if b ~= nil then
      if #self.buffer - e < ignore_tail_bytes then
        -- Wait a bit longer, the next timer is pending
        return false
      end
      self.buffer = self.buffer:sub(e + 1)
      log.debug("prev state: " .. self:_get_state_name())
      self.state = func(self, m1, m2)
      log.info("new state: " .. self:_get_state_name())
      return true
    end
  end
  return false
end

function C:delay_elapsed(byte_count)
  if self.parsing_progress[1] ~= byte_count then
    -- Another parsing is already in progress, return to this mark later
    self:_delay_parsing(1, byte_count)
    return
  end
  -- Detect whether new input has been received before the previous
  -- delay elapsed.
  local ignore_tail_bytes = self.byte_count - byte_count
  while self:_search(ignore_tail_bytes) do
  end
  -- Pop the current mark allowing parsing the next chunk
  table.remove(self.parsing_progress, 1)
end

return C
