Engine = require "engine"
config = require "config"

subtests = {}
if config["gdb"] != nil
    subtests['gdb'] = {'launch': ' dd\n',
                       'tbreak_main': 'tbreak main\n'}
if config["lldb"] != nil
    subtests['lldb'] = {'launch': ' dl\n',
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
            eng\input spec["launch"], 1000
            eng\input "<esc>"

        it "GdbDebugStop", ->
            eng\input ":GdbDebugStop<cr>"
            assert.are.equal(1, eng\eval "tabpagenr('$')")
            -- Check that no new buffers have left
            assert.are.equal(numBufs, eng\countBuffers!)

        it "terminal ZZ", ->
            eng\input "ZZ"
            assert.are.equal(1, eng\eval "tabpagenr('$')")
            -- Check that no new buffers have left
            assert.are.equal(numBufs, eng\countBuffers!)

        it "jump ZZ", ->
            eng\input "<c-w>w"
            eng\input "ZZ"
            assert.are.equal(1, eng\eval "tabpagenr('$')")
            -- Check that no new buffers have left
            assert.are.equal(numBufs, eng\countBuffers!)
