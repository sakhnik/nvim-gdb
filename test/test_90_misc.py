'''Test keymaps are defined in proper buffers.'''


def test_buffer_keymaps(eng, post):
    '''Ensure that keymaps are defined in the jump window when navigating.'''
    assert post

    def _get_map():
        return eng.eval('execute("map <c-n>")')

    eng.feed(":e config.py\n")
    assert "No mapping found" in _get_map()
    eng.feed(' dp')
    eng.feed('\n', 300)
    eng.feed('<esc>')
    assert "GdbFrameDown" in _get_map()
    eng.feed('<c-w>w')
    assert "GdbFrameDown" in _get_map()
    eng.feed('gt')
    assert "No mapping found" in _get_map()
    eng.feed('gt')
    assert "GdbFrameDown" in _get_map()
