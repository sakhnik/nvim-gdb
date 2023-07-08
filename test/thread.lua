local Thread = {}
Thread.__index = Thread

function Thread.create(func, on_stuck)
  local co = setmetatable({}, Thread)
  co.watchdog_flag = false
  co.watchdog_timer = vim.loop.new_timer()
  co.watchdog_timer:start(5000, 5000, function ()
    if co.watchdog_flag then
      co.watchdog_timer:stop()
      co.watchdog_timer:close()
      vim.schedule(on_stuck)
    end
    co.watchdog_flag = true
  end)
  Thread.it = co
  co.co = coroutine.create(function() func(co) end)
  co:step()
  return co
end

function Thread:cleanup()
  self.watchdog_timer:stop()
  self.watchdog_timer:close()
end

function Thread:step()
  self.watchdog_flag = false
  local success, ms = coroutine.resume(self.co)
  if not success or coroutine.status(self.co) == "dead" then
    return
  end
  if type(ms) == 'number' and ms > 0 then
    vim.defer_fn(function() self:step() end, ms)
  else
    vim.schedule(function() self:step() end)
  end
end

function Thread.y(ms)
  coroutine.yield(ms)
end

return Thread
