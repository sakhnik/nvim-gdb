-- source: 50_command_spec.moon
backends = require "backends"


expose "Command", ->
    eng = require "engine"

    after_each ->
        eng\exe "GdbDebugStop"
        assert.are.equal 1, eng\eval "tabpagenr('$')"
        assert.are.same {}, eng\getSigns!

    describe "#gdb", ->
        back = backends.gdb
        if back != nil
            it "info", ->
                eng\feed back.launch, 1000
                eng\feed back.tbreak_main
                eng\feed 'run\n', 1000
                eng\feed '<esc>'
                eng\feed '<f10>'
                assert.are.same '$1 = 0', eng\eval "luaeval('gdb.customCommand(\"print i\")')"
                assert.are.same 'i = 0', eng\eval "luaeval('gdb.customCommand(\"info locals\")')"
