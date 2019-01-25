-- source: 10_generic_spec.moon
backends = require "backends"


expose "Generic", ->
    eng = require "engine"

    after_each ->
        eng\exe "GdbDebugStop"
        assert.are.equal 1, eng\eval "tabpagenr('$')"
        assert.are.same {'', {}}, eng\getSigns!

    describe "#smoke", ->
        for backend, spec in pairs(backends)
            it "#" .. backend, ->
                eng\feed spec.launch, 1000
                eng\feed spec.tbreak_main
                eng\feed 'run\n', 1000
                eng\feed '<esc>'

                assert.are.same {'test.cpp:17', {}}, eng\getSigns!

                eng\feed '<f10>'
                assert.are.same {'test.cpp:19', {}}, eng\getSigns!

                eng\feed '<f11>'
                assert.are.same {'test.cpp:10', {}}, eng\getSigns!

                eng\feed '<c-p>'
                assert.are.same {'test.cpp:19', {}}, eng\getSigns!

                eng\feed '<c-n>'
                assert.are.same {'test.cpp:10', {}}, eng\getSigns!

                eng\feed '<f12>'
                signs = eng\getSigns!
                -- different for different compilers
                exp = {'test.cpp:17': true, 'test.cpp:19': true}
                assert.are_not.equal nil, signs[1]
                assert.are.same {}, signs[2]

                eng\feed '<f5>'
                assert.are.same {'', {}}, eng\getSigns!

    describe "#break", ->
        -- Test toggling breakpoints.
        for backend, spec in pairs(backends)
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

    it "multiview", ->
        -- Test multiple views.
        names = [k for k,_ in pairs(backends)]
        backend1 = names[1]
        backend2 = #names > 1 and names[2] or backend1

        -- Launch the first backend
        eng\feed backends[backend1].launch, 1000
        eng\feed backends[backend1].tbreak_main
        eng\feed 'run\n', 1000
        eng\feed '<esc>'
        eng\feed '<c-w>w'
        eng\feed ':11<cr>'
        eng\feed '<f8>'
        eng\feed '<f10>'
        eng\feed '<f11>'

        assert.are.same {'test.cpp:10', {11}}, eng\getSigns!

        -- Then launch the second backend
        eng\feed backends[backend2].launch, 1000
        eng\feed backends[backend2].tbreak_main
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

        -- The last debugger is quit in the after_each

    describe "interrupt", ->
        -- Test interrupt.
        for backend, spec in pairs(backends)
            it '#'..backend, ->
                eng\feed spec.launch, 1000
                eng\feed 'run 4294967295\n', 1000
                eng\feed '<esc>'
                eng\feed ':GdbInterrupt\n', 300

                assert.are.same {'test.cpp:22', {}}, eng\getSigns!

    describe "until", ->
        for backend, spec in pairs(backends)
            it '#'..backend, ->
                eng\feed spec.launch, 1000
                eng\feed spec.tbreak_main
                eng\feed 'run\n', 1000
                eng\feed '<esc>'

                eng\feed '<c-w>w'
                eng\feed ':21<cr>'
                eng\feed '<f4>'

                assert.are.same {'test.cpp:21', {}}, eng\getSigns!

    describe 'program exit', ->
        -- Test the cursor is hidden after program end.
        for backend, spec in pairs(backends)
            it '#'..backend, ->
                eng\feed spec.launch, 1000
                eng\feed spec.tbreak_main
                eng\feed 'run\n', 1000
                eng\feed '<esc>'

                eng\feed '<f5>'
                assert.are.same {'', {}}, eng\getSigns!

    describe '#eval', ->
        -- Test eval <cword>.
        for backend, spec in pairs(backends)
            it '#'..backend, ->
                eng\feed spec.launch, 1000
                eng\feed spec.tbreak_main
                eng\feed 'run\n', 1000
                eng\feed '<esc>'
                eng\feed '<c-w>w'
                eng\feed '<f10>'

                eng\feed '^<f9>'
                assert.are.same 'print Foo', eng\eval 'luaeval("gdb.getLastCommand()")'

                eng\feed '/Lib::Baz\n'
                eng\feed 'vt('
                eng\feed ':GdbEvalRange\n'
                assert.are.equal 'print Lib::Baz', eng\eval 'luaeval("gdb.getLastCommand()")'
