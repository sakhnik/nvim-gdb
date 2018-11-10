rex = require "rex_pcre"

class Scm
    new: =>
        @running = {}
        @paused = {}
        @state = nil

    addTrans: (state, rx, handler) =>
        state[#state + 1] = {rx, handler}

    -- Transition "paused" -> "continue"
    continue: (...) =>
        @state = @running
        gdb.cursor.display(0)

    -- Transition "paused" -> "paused": jump to the frame location
    jump: (file, line, ...) =>
        gdb.win.jump(file, line)

    -- Transition "paused" -> "paused": refresh breakpoints in the current file
    query: (...) =>
        gdb.win.queryBreakpoints()

    -- Transition "running" -> "pause"
    pause: (...) =>
        @state = @paused
        gdb.win.queryBreakpoints()

    isPaused: =>
        @state == @paused

    isRunning: =>
        @state == @running

    feed: (line) =>
        for k, v in ipairs(@state)
            m1, m2 = v[1]\match(line)
            if m1
                v[2](self, m1, m2)
                break


Init = (backend) ->
    backend.initScm!

ret =
    Scm: Scm
    init: Init

ret
