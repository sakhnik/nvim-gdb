Engine = require "engine"
backends = require "backends"

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
