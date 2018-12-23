
-- Common SCM implementation for the integrated backends
class BaseScm
    new: =>
        @running = {}   -- The running state {{matcher, matchingFunc, handler}}
        @paused = {}    -- The paused state {{matcher, matchingFunc, handler}}
        @state = nil    -- Current state (either @running or @paused)

    -- Add a new transition for a given state using {matcher, matchingFunc}
    -- Call the handler when matched.
    addTrans: (state, matcher, func) =>
        state[#state + 1] = {matcher, func}

    isPaused: =>
        @state == @paused

    isRunning: =>
        @state == @running

    -- Process a line of the debugger output through the SCM.
    feed: (line) =>
        -- If there is a matcher matching the line, call its handler.
        for _, v in ipairs(@state)
            matcher, func = unpack(v)
            newState = func(matcher, line)
            if newState != nil
                @state = newState
                break

BaseScm
