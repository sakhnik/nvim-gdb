'''Test keymaps are defined in proper buffers.'''


def test_buffer_keymaps(eng, post):
    '''Ensure that keymaps are defined in the jump window when navigating.'''
    assert post

    def _get_map():
        return eng.eval('execute("map <c-n>")')

    eng.feed(":e main.py\n")
    assert eng.wait_for(_get_map, lambda res: "No mapping found" in res) is None
    eng.feed(' dp')
    eng.feed('\n', 1000)
    eng.feed('<esc>')
    assert eng.wait_for(_get_map, lambda res: "GdbFrameDown" in res) is None
    eng.feed('<c-w>w')
    assert eng.wait_for(_get_map, lambda res: "GdbFrameDown" in res) is None
    eng.feed(':tabnew\n')
    eng.feed(':e config.py\n')
    assert eng.wait_for(_get_map, lambda res: "No mapping found" in res) is None
    eng.feed('gt')
    assert eng.wait_for(_get_map, lambda res: "GdbFrameDown" in res) is None
    eng.feed(':tabclose! $\n')
