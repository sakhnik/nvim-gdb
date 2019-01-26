-- source: 40_keymap_spec.moon

expose "#keymap", ->
    eng = require "engine"

    --before_each ->
        --eng\exe 'let g:nvim_config_orig = g:nvim_config'

    after_each ->
        eng\exe "GdbDebugStop"
        assert.are.equal 1, eng\eval "tabpagenr('$')"
        assert.are.same {''}, eng\getSigns!
        eng\exe 'source keymap_cleanup.vim'

    launch = ->
        eng\feed ":GdbStart ./dummy-gdb.sh\n"

    it 'hooks', ->
        -- Test custom programmable keymaps.
        eng\exe "source keymap_hooks.vim"
        launch!

        assert.are.same 0, eng\eval 'g:test_tkeymap'
        eng\feed '~tkm'
        assert.are.same 1, eng\eval 'g:test_tkeymap'
        eng\feed '<esc>'
        assert.are.same 0, eng\eval 'g:test_keymap'
        eng\feed '~tn'
        assert.are.same 1, eng\eval 'g:test_keymap'
        eng\exe 'let g:test_tkeymap = 0 | let g:test_keymap = 0'
        eng\feed '<c-w>w'
        assert.are.same 0, eng\eval 'g:test_keymap'
        eng\feed '~tn'
        assert.are.same 1, eng\eval 'g:test_keymap'
        eng\exe 'let g:test_keymap = 0'

    it 'conflict', ->
        eng\exe "let g:nvimgdb_config = {'key_next': '<f5>', 'key_prev': '<f5>'}"
        launch!

        count = eng\eval 'luaeval("(function() local c = 0; for _,_ in pairs(gdb.getKeymaps():getConfig()) do c = c + 1 end return c end)()")'
        assert.are.same 1, count
        -- Check that the coursor is moving freely without stucking
        eng\feed '<esc>'
        eng\feed '<c-w>w'
        eng\feed '<c-w>w'

    it 'override', ->
        eng\exe "let g:nvimgdb_config_override = {'key_next': '<f2>'}"
        launch!
        key = eng\eval 'luaeval("gdb.getKeymaps():getConfig().key_next")'
        assert.are.same '<f2>', key

    it 'override priority', ->
        -- Check that a config override assumes priority in a conflict
        eng\exe "let g:nvimgdb_config_override = {'key_next': '<f8>'}"
        launch!
        res = eng\eval 'luaeval("gdb.getKeymaps():getConfig().key_breakpoint == nil")'
        assert.are.same true, res

    it 'override one', ->
        eng\exe "let g:nvimgdb_key_next = '<f3>'"
        launch!
        key = eng\eval 'luaeval("gdb.getKeymaps():getConfig().key_next")'
        assert.are.same '<f3>', key

    it 'override one priority', ->
        eng\exe "let g:nvimgdb_key_next = '<f8>'"
        launch!
        res = eng\eval 'luaeval("gdb.getKeymaps():getConfig().key_breakpoint == nil")'
        assert.are.same true, res

    it 'overall', ->
        eng\exe "let g:nvimgdb_config_override = {'key_next': '<f5>'}"
        eng\exe "let g:nvimgdb_key_step = '<f5>'"
        launch!
        res = eng\eval 'luaeval("gdb.getKeymaps():getConfig().key_continue == nil")'
        assert.are.same true, res
        res = eng\eval 'luaeval("gdb.getKeymaps():getConfig().key_next == nil")'
        assert.are.same true, res
        key = eng\eval 'luaeval("gdb.getKeymaps():getConfig().key_step")'
        assert.are.same '<f5>', key
