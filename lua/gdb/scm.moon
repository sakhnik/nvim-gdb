rex = require "rex_pcre"

-- Abstract interface for a debugger state machine
class Scm
    isPaused: => assert(nil, "Not implemented")     -- is the inferior paused?
    isRunning: => assert(nil, "Not implemented")    -- is the inferior running?
    feed: (line) => assert(nil, "Not implemented")  -- process a single line

-- Common SCM implementation for the integrated backends
class BaseScm extends Scm
    new: (cursor, win) =>
        assert cursor.__class.__name == "Cursor"
        assert win.__class.__name == "Win"
        @cursor = cursor
        @win = win

        @running = {}   -- The running state {{matcher, matchingFunc, handler}}
        @paused = {}    -- The paused state {{matcher, matchingFunc, handler}}
        @state = nil    -- Current state (either @running or @paused)

    -- Add a new transition for a given state using {matcher, matchingFunc}
    -- Call the handler when matched.
    addTrans: (state, matcher, func, handler) =>
        state[#state + 1] = {matcher, func, handler}

    -- Transition "paused" -> "continue"
    continue: (...) =>
        @state = @running
        @cursor\hide()

    -- Transition "paused" -> "paused": jump to the frame location
    jump: (file, line, ...) =>
        @win\jump(file, line)

    -- Transition "paused" -> "paused": refresh breakpoints in the current file
    query: (...) =>
        @win\queryBreakpoints!

    -- Transition "running" -> "pause"
    pause: (...) =>
        @state = @paused
        @win\queryBreakpoints!

    isPaused: =>
        @state == @paused

    isRunning: =>
        @state == @running

    feed: (line) =>
        for k, v in ipairs(@state)
            matcher, func, handler = unpack(v)
            m1, m2 = func(matcher, line)
            if m1
                handler(self, m1, m2)
                break


Init = (backend, ...) ->
    backend.initScm(backend, ...)

ret =
    BaseScm: BaseScm
    init: Init

ret
