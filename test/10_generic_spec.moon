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

    describe "#quit", ->
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

                assert.are.same {'test.cpp:17', {}}, eng\getSigns!

                eng\feed '<f10>'
                assert.are.same {'test.cpp:19', {}}, eng\getSigns!

                eng\feed '<f11>'
                assert.are.same {'test.cpp:10', {}}, eng\getSigns!

                eng\feed '<f12>'
                signs = eng\getSigns!
                -- different for different compilers
                exp = {'test.cpp:17': true, 'test.cpp:19': true}
                assert.are_not.equal nil, signs[1]
                assert.are.same {}, signs[2]

                eng\feed '<f5>'
                assert.are.same {'', {}}, eng\getSigns!

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
                assert.are.same {'', {5}}, eng\getSigns!

                eng\exe "GdbRun", 1000
                assert.are.same {'test.cpp:5', {5}}, eng\getSigns!

                eng\feed '<f8>'
                assert.are.same {'test.cpp:5', {}}, eng\getSigns!

                eng\exe 'GdbDebugStop'

    describe '#break cleanup', ->
        -- Verify that breakpoints are cleaned up after session end.
        for backend, spec in pairs(subtests)
            it '#' .. backend, ->
                eng\feed spec.launch, 1000
                eng\feed '<esc><c-w>k'
                eng\feed ':e src/test.cpp\n'
                eng\feed ':5<cr>'
                eng\feed '<f8>'
                assert.are.same {'', {5}}, eng\getSigns!

                eng\exe "GdbDebugStop"
                assert.are.same {'', {}}, eng\getSigns!

    it "multiview", ->
        -- Test multiple views.
        backends = [k for k,_ in pairs(subtests)]
        backend1 = backends[1]
        backend2 = #backends > 1 and backends[2] or backend1

        -- Launch the first backend
        eng\feed subtests[backend1].launch, 1000
        eng\feed subtests[backend1].tbreak_main
        eng\feed 'run\n', 1000
        eng\feed '<esc>'
        eng\feed '<c-w>w'
        eng\feed ':11<cr>'
        eng\feed '<f8>'
        eng\feed '<f10>'
        eng\feed '<f11>'

        assert.are.same {'test.cpp:10', {11}}, eng\getSigns!

        -- Then launch the second backend
        eng\feed subtests[backend2].launch, 1000
        eng\feed subtests[backend2].tbreak_main
        eng\feed 'run\n', 1000
        eng\feed '<esc>'
        eng\feed '<c-w>w'
        eng\feed ':5<cr>'
        eng\feed '<f8>'
        eng\feed ':12<cr>'
        eng\feed '<f8>'
        eng\feed '<f10>'

        assert.are.same {'test.cpp:19', {5, 12}}, eng\getSigns!

        -- Switch to the first backend
        eng\feed '2gt'
        assert.are.same {'test.cpp:10', {11}}, eng\getSigns!

        -- Quit
        eng\feed 'ZZ'

        -- Switch back to the second backend
        assert.are.same {'test.cpp:19', {5, 12}}, eng\getSigns!

        -- Quit LLDB
        eng\feed 'ZZ'
        assert.are.same 1, eng\eval "tabpagenr('$')"
