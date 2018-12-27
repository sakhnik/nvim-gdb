-- source: 05_quit_spec.moon

expose "#quit", ->
    numBufs = 0
    eng = require "engine"

    before_each ->
        numBufs = eng\countBuffers!
        eng\feed ":GdbStart ./dummy-gdb.sh<cr>"
        eng\feed '<esc>'
    after_each ->
        -- Check that no new buffers have left
        assert.are.equal numBufs, eng\countBuffers!
        assert.are.equal 1, eng\eval "tabpagenr('$')"

    it "GdbDebugStop", ->
        eng\feed ":GdbDebugStop<cr>"

    it "terminal ZZ", ->
        eng\feed "ZZ"

    it "jump ZZ", ->
        eng\feed "<c-w>w"
        eng\feed "ZZ"
