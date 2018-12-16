Engine = require "engine"
config = require "config"

subtests = {}
if config.gdb != nil
    subtests.gdb = {'launch': ' dd\n',
                    'tbreak_main': 'tbreak main\n'}
if config.lldb != nil
    subtests.lldb = {'launch': ' dl\n',
                     'tbreak_main': 'breakpoint set -o true -n main\n'}

describe "Generic", ->
    eng = nil

    setup ->
        eng = Engine!
    teardown ->
        eng\close!

    describe "exit on window close", ->
        -- Use random backend, assuming all they behave the same way.
        backend, spec = next(subtests)
        numBufs = 0

        before_each ->
            numBufs = eng\countBuffers!
            eng\feed spec.launch, 1000
            eng\feed "<esc>"

        after_each ->
            assert.are.equal(1, eng\eval "tabpagenr('$')")
            -- Check that no new buffers have left
            assert.are.equal(numBufs, eng\countBuffers!)

        it "GdbDebugStop", ->
            eng\feed ":GdbDebugStop<cr>"

        it "terminal ZZ", ->
            eng\feed "ZZ"

        it "jump ZZ", ->
            eng\feed "<c-w>w"
            eng\feed "ZZ"

    describe "#smoke", ->
        for backend, spec in pairs(subtests)
            it "#" .. backend, ->
                eng\feed spec.launch, 1000
                eng\feed spec.tbreak_main
                eng\feed 'run\n', 1000
                eng\feed '<esc>'
                ----print(eng\eval "execute('history c')")

                cur, breaks = eng\getSigns!
                assert.are.equal 'test.cpp:17', cur
                assert.are.same {}, breaks

                eng\feed '<f10>'
                cur, breaks = eng\getSigns!
                assert.are.equal 'test.cpp:19', cur
                assert.are.same {}, breaks

                eng\feed '<f11>'
                cur, breaks = eng\getSigns!
                assert.are.equal 'test.cpp:10', cur
                assert.are.same {}, breaks

                eng\feed '<f12>'
                cur, breaks = eng\getSigns!
                -- different for different compilers
                exp = {'test.cpp:17': true, 'test.cpp:19': true}
                assert.are_not.equal nil, exp[cur]
                assert.are.same {}, breaks

                eng\feed '<f5>'
                cur, breaks = eng\getSigns!
                assert.is.falsy cur
                assert.are.same {}, breaks

                eng\exe 'GdbDebugStop'

    describe "#break", ->
        -- Test toggling breakpoints.
        for backend, spec in pairs(subtests)
            it "#" .. backend, ->
                -- TODO: Investigate socket connection race when the delay is small
                -- here, like 1ms
                eng\feed spec.launch, 1000
                eng\feed '<esc><c-w>k'
                eng\feed ":e src/test.cpp\n"
                eng\feed ':5<cr>'
                eng\feed '<f8>'
                cur, breaks = eng\getSigns!
                assert.is.falsy cur
                assert.are.same {5}, breaks

                eng\exe "GdbRun", 1000
                cur, breaks = eng\getSigns!
                assert.are.same 'test.cpp:5', cur
                assert.are.same {5}, breaks

                eng\feed '<f8>'
                cur, breaks = eng\getSigns!
                assert.are.same 'test.cpp:5', cur
                assert.are.same {}, breaks

                eng\exe 'GdbDebugStop'
