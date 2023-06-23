-- Queue for the side channel proxy responses
-- vim: set et ts=2 sw=2:
local log = require'nvimgdb.log'

local Queue = {}
Queue.__index = Queue

-- @class Queue @queue for the proxy responses
-- @field private queue table<number, any> @numbered responses
-- @field private tail number @index at which new items are added to the queue
-- @field private head number @inex at which the items are dequeued
function Queue.new()
  log.debug({"function Queue.new()"})
  local self = setmetatable({}, Queue)
  self.queue = {}
  self.head = 0
  self.tail = 0
  return self
end

-- Destructor
function Queue:cleanup()
  self.queue = nil
end

-- Add an item to the queue
-- @private item any @an item to enqueue (response from the proxy)
function Queue:put(item)
  if self.head <= self.tail then
    self.queue[self.tail] = item
  end
  self.tail = self.tail + 1
end

-- Check the head element of the queue
-- @return any @the head of the queue
function Queue:peek()
  return self.queue[self.head]
end

-- Dequeue and return the head item of the queue
-- @return any @the head item of the queue
function Queue:take()
  local item = self.queue[self.head]
  self.queue[self.head] = nil
  self.head = self.head + 1
  return item
end

-- Skip the head item of the queue
function Queue:skip()
  self.queue[self.head] = nil
  self.head = self.head + 1
end

return Queue
