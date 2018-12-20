-- source: 20_breakpoint_spec.moon
backends = require "backends"
unistd = require "posix.unistd"

expose "#break", ->
    eng = require "engine"

    after_each ->
        eng\exe 'GdbDebugStop'
        assert.are.equal 1, eng\eval "tabpagenr('$')"
        assert.are.same {'', {}}, eng\getSigns!

    describe 'detect', ->
        -- Verify manual breakpoint is detected.
        for backend, spec in pairs(backends)
            it '#'..backend, ->
                eng\feed spec.launch, 1000
                eng\feed spec.break_main
                eng\feed 'run\n', 1000

                assert.are.same {'test.cpp:17', {17}}, eng\getSigns!

    describe 'cd', ->
        -- Verify manual breakpoint is detected from a random directory.
        old_cwd = unistd.getcwd()
        exe_path = old_cwd .. '/' .. 'a.out'

        subs = {'gdb': string.format(":GdbStart gdb -q %s\n", exe_path),
                'lldb': string.format(":GdbStartLLDB lldb %s\n", exe_path)}

        before_each ->
            eng\exe 'cd /tmp'
        after_each ->
            eng\exe 'cd '..old_cwd

        for backend, spec in pairs(backends)
            it '#'..backend, ->
                eng\feed subs[backend], 1000
                eng\feed spec.break_main
                eng\feed 'run\n', 1000

                assert.are.same {'test.cpp:17', {17}}, eng\getSigns!

    describe 'navigate', ->
        -- Verify that breakpoints stay when source code is navigated.
        for backend, spec in pairs(backends)
            it '#'..backend, ->
                eng\feed spec.launch, 1000
                eng\feed spec.break_bar
                eng\feed "<esc>:wincmd k<cr>"
                eng\feed ":e src/test.cpp\n"
                eng\feed ":10<cr>"
                eng\feed "<f8>"

                assert.are.same {'', {5, 10}}, eng\getSigns!

                -- Go to another file
                eng\feed ":e src/lib.hpp\n"
                assert.are.same {'', {}}, eng\getSigns!
                eng\feed ":8\n"
                eng\feed "<f8>"
                assert.are.same {'', {8}}, eng\getSigns!

                -- Return to the first file
                eng\feed ":e src/test.cpp\n"
                assert.are.same {'', {5, 10}}, eng\getSigns!

    describe 'clear all', ->
        -- Verify that can clear all breakpoints.
        for backend, spec in pairs(backends)
            it '#'..backend, ->
                eng\feed spec.launch, 1000
                eng\feed spec.break_bar
                eng\feed spec.break_main
                eng\feed "<esc>:wincmd k<cr>"
                eng\feed ":e src/test.cpp\n"
                eng\feed ":10<cr>"
                eng\feed "<f8>"

                assert.are.same {'', {5,10,17}}, eng\getSigns!

                eng\feed ":GdbBreakpointClearAll\n", 1000
                assert.are.same {'', {}}, eng\getSigns!
