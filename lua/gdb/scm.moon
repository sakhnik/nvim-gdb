
-- Common SCM implementation for the integrated backends
class BaseScm
    new: =>
        @running = {}   -- The running state {{matcher, matchingFunc, handler}}
        @paused = {}    -- The paused state {{matcher, matchingFunc, handler}}
        @state = nil    -- Current state (either @running or @paused)

    -- Add a new transition for a given state using {matcher, matchingFunc}
    -- Call the handler when matched.
    addTrans: (state, newState, matcher, func, handler) =>
        state[#state + 1] = {matcher, func, newState, handler}

    isPaused: =>
        @state == @paused

    isRunning: =>
        @state == @running

    -- Process a line of the debugger output through the SCM.
    feed: (line) =>
        -- If there is a matcher matching the line, call its handler.
        for _, v in ipairs(@state)
            matcher, func, newState, handler = unpack(v)
            m1, m2 = func(matcher, line)
            if m1
                handler(m1, m2)
                @state = newState
                break

BaseScm
