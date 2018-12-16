Engine = require "engine"
backends = require "backends"
unistd = require "posix.unistd"

describe "#break", ->
    eng = nil

    setup ->
        eng = Engine!
    teardown ->
        eng\close!

    after_each ->
        eng\exe 'GdbDebugStop'
        assert.are.equal(1, eng\eval "tabpagenr('$')")
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
        break_bar = {"gdb": "break Bar\n", "lldb": "breakpoint set --fullname Bar\n"}
        for backend, spec in pairs(backends)
            it '#'..backend, ->
                eng\feed spec.launch, 1000
                eng\feed break_bar[backend]
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

    --def test_40_clear_all(self):
    --    """=> Verify that can clear all breakpoints."""
    --    break_bar = {"gdb": "break Bar\n", "lldb": "breakpoint set --fullname Bar\n"}
    --    for backend, spec in subtests.items():
    --        with self.subTest(backend=backend):
    --            e.Ty(spec['launch'], delay=1)
    --            e.Ty(break_bar[backend])
    --            e.Ty(spec['break_main'])
    --            e.In("<esc>:wincmd k<cr>")
    --            e.In(":e src/test.cpp\n")
    --            e.In(":10<cr>")
    --            e.In("<f8>")

    --            cur, breaks = e.GetSigns()
    --            self.assertFalse(cur)
    --            self.assertEqual([5, 10, 17], breaks)

    --            e.Ty(":GdbBreakpointClearAll\n", delay=1)
    --            cur, breaks = e.GetSigns()
    --            self.assertFalse(cur)
    --            self.assertFalse(breaks)

    --            e.In('ZZ')
