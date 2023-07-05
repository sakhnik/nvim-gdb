-- custom_output.lua

_G.test_result = {}

local output = function(options)
  local busted = require("busted")
  local handler = require("busted.outputHandlers.base")()

  handler.testStart = function(element, parent)
    print("Start " .. parent.name .. "::" .. element.name)
  end

  handler.testEnd = function(element, parent, status, trace)
    print(status .. " " .. parent.name .. "::" .. element.name)
    table.insert(_G.test_result, {element, parent, status, trace})
  end

  busted.subscribe({'test', 'start'}, handler.testStart)
  busted.subscribe({'test', 'end'}, handler.testEnd)

  return handler
end

return output
