rex = require "rex_pcre"

-- Abstract interface for a debugger state machine
class Scm
    isPaused: => assert(nil, "Not implemented")     -- is the inferior paused?
    isRunning: => assert(nil, "Not implemented")    -- is the inferior running?
    feed: (line) => assert(nil, "Not implemented")  -- process a single line

-- Common SCM implementation for the integrated backends
class BaseScm extends Scm
    new: =>
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
        gdb.app.dispatch("getCursor")\hide()

    -- Transition "paused" -> "paused": jump to the frame location
    jump: (file, line, ...) =>
        gdb.app.dispatch("getWin")\jump(file, line)

    -- Transition "paused" -> "paused": refresh breakpoints in the current file
    query: (...) =>
        gdb.app.dispatch("getWin")\queryBreakpoints!

    -- Transition "running" -> "pause"
    pause: (...) =>
        @state = @paused
        gdb.app.dispatch("getWin")\queryBreakpoints!

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


Init = (backend) ->
    backend.initScm!

ret =
    BaseScm: BaseScm
    init: Init

ret
