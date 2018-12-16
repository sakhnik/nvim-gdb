Engine = require "engine"
backends = require "backends"


describe "#quit", ->
    eng = nil
    backend, spec = next(backends)
    numBufs = 0

    setup ->
        eng = Engine!
    teardown ->
        eng\close!
    before_each ->
        numBufs = eng\countBuffers!
        eng\feed spec.launch, 1000
        eng\feed "<esc>"
    after_each ->
        -- Check that no new buffers have left
        assert.are.equal(numBufs, eng\countBuffers!)
        assert.are.equal(1, eng\eval "tabpagenr('$')")

    it "GdbDebugStop", ->
        eng\feed ":GdbDebugStop<cr>"

    it "terminal ZZ", ->
        eng\feed "ZZ"

    it "jump ZZ", ->
        eng\feed "<c-w>w"
        eng\feed "ZZ"
