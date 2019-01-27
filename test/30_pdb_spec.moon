-- source: 30_pdb_spec.moon
backends = require "backends"

expose '#pdb', ->
    eng = require "engine"

    after_each ->
        eng\exe 'GdbDebugStop'
        assert.are.equal 1, eng\eval "tabpagenr('$')"
        assert.are.same {}, eng\getSigns!

    it '#smoke', ->
        -- Test a generic use case.
        eng\feed ' dp'
        eng\feed '\n', 300
        eng\feed 'tbreak _main\n'
        eng\feed 'cont\n'
        eng\feed '<esc>'

        assert.are.same {'cur': 'main.py:15'}, eng\getSigns!

        eng\feed '<f10>'
        assert.are.same {'cur': 'main.py:16'}, eng\getSigns!

        eng\feed '<f11>'
        assert.are.same {'cur': 'main.py:8'}, eng\getSigns!

        eng\feed '<c-p>'
        assert.are.same {'cur': 'main.py:16'}, eng\getSigns!

        eng\feed '<c-n>'
        assert.are.same {'cur': 'main.py:8'}, eng\getSigns!

        eng\feed '<f12>'
        assert.are.same {'cur': 'main.py:10'}, eng\getSigns!

        eng\feed '<f5>', 1200
        assert.are.same {'cur': 'main.py:1'}, eng\getSigns!

    it '#break', ->
        -- Test toggling breakpoints.
        eng\feed ' dp'
        eng\feed '\n', 300
        eng\feed '<esc>'

        eng\feed '<esc><c-w>k'
        eng\feed ':e main.py\n'
        eng\feed ':5<cr>'
        eng\feed '<f8>'
        assert.are.same {'cur': 'main.py:1', 'break': {[1]: {5}}}, eng\getSigns!

        eng\exe 'GdbContinue'
        assert.are.same {'cur': 'main.py:5', 'break': {[1]: {5}}}, eng\getSigns!

        eng\feed '<f8>', 300
        assert.are.same {'cur': 'main.py:5'}, eng\getSigns!

    it 'navigation', ->
        -- Test toggling breakpoints while navigating.
        eng\feed ' dp'
        eng\feed '\n', 300
        eng\feed '<esc>'

        eng\feed '<esc><c-w>k'
        eng\feed ':5<cr>'
        eng\feed '<f8>'
        assert.are.same {'cur': 'main.py:1', 'break': {[1]: {5}}}, eng\getSigns!

        -- Go to another file
        eng\feed ':e lib.py\n'
        eng\feed ':3\n'
        eng\feed '<f8>'
        assert.are.same {'cur': 'main.py:1', 'break': {[1]: {3}}}, eng\getSigns!
        eng\feed ':5\n'
        eng\feed '<f8>'
        assert.are.same {'cur': 'main.py:1', 'break': {[1]: {3,5}}}, eng\getSigns!

        -- Return to the original file
        eng\feed ':e main.py\n'
        assert.are.same {'cur': 'main.py:1', 'break': {[1]: {5}}}, eng\getSigns!

    it 'until', ->
        -- Test run until line.
        eng\feed ' dp'
        eng\feed '\n', 300
        eng\feed 'tbreak _main\n'
        eng\feed 'cont\n'
        eng\feed '<esc>'

        eng\feed '<c-w>w'
        eng\feed ':18<cr>'
        eng\feed '<f4>'

        signs = eng\getSigns!
        -- While the check works fine locally, doesn't work in Travis.
        -- Probably, because of different versions of Python interpreter.
        if os.getenv("TRAVIS_BUILD_ID") == nil
            assert.are.same 'main.py:18', signs.cur
        assert.are.same nil, signs.break
        assert.are.same nil, signs.breakM

    it '#eval', ->
        eng\feed ' dp'
        eng\feed '\n', 300
        eng\feed 'tbreak _main\n'
        eng\feed 'cont\n'
        eng\feed '<esc>'
        eng\feed '<c-w>w'
        eng\feed '<f10>'

        eng\feed '^<f9>'
        assert.are.same 'print(_Foo)', eng\eval 'luaeval("gdb.getLastCommand()")'

        eng\feed 'viW'
        eng\feed ':GdbEvalRange\n'
        assert.are.same 'print(_Foo(i))', eng\eval 'luaeval("gdb.getLastCommand()")'
