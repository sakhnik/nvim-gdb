-- source: 40_keymap_spec.moon
backends = require "backends"

expose "#keymap", ->
    backend, spec = next backends
    eng = require "engine"

    after_each ->
        eng\exe "GdbDebugStop"
        assert.are.equal 1, eng\eval "tabpagenr('$')"
        assert.are.same {'', {}}, eng\getSigns!

    it 'hooks', ->
        -- Test custom programmable keymaps.
        eng\feed spec.launch, 1000
        eng\feed spec.tbreak_main
        eng\feed 'run\n', 1000

        assert.are.same 0, eng\eval 'g:test_tkeymap'
        eng\feed '~tkm'
        assert.are.same 1, eng\eval 'g:test_tkeymap'
        eng\feed '<esc>'
        assert.are.same 0, eng\eval 'g:test_keymap'
        eng\feed '~tn'
        assert.are.same 1, eng\eval 'g:test_keymap'
        eng\feed ':let g:test_tkeymap = 0 | let g:test_keymap = 0<cr>'
        eng\feed '<c-w>w'
        assert.are.same 0, eng\eval 'g:test_keymap'
        eng\feed '~tn'
        assert.are.same 1, eng\eval 'g:test_keymap'
        eng\feed ':let g:test_keymap = 0<cr>'
