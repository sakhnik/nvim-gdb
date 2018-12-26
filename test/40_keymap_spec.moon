-- source: 40_keymap_spec.moon

expose "#keymap", ->
    eng = require "engine"

    --before_each ->
        --eng\exe 'let g:nvim_config_orig = g:nvim_config'

    after_each ->
        eng\exe "GdbDebugStop"
        assert.are.equal 1, eng\eval "tabpagenr('$')"
        assert.are.same {'', {}}, eng\getSigns!
        eng\exe 'source keymap_cleanup.vim'

    launch = ->
        eng\feed ":GdbStart ls\n", 10

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
