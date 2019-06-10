
def test_buffer_keymaps(eng, post):
    '''Ensure that keymaps are defined in the jump window when navigating.'''
    get_map = lambda: eng.eval('execute("map <c-n>")')
    eng.feed(":e config.py\n")
    assert "No mapping found" in get_map()
    eng.feed(' dp')
    eng.feed('\n', 300)
    eng.feed('<esc>')
    assert "GdbFrameDown" in get_map()
    eng.feed('<c-w>w')
    assert "GdbFrameDown" in get_map()
    eng.feed('gt')
    assert "No mapping found" in get_map()
    eng.feed('gt')
    assert "GdbFrameDown" in get_map()
