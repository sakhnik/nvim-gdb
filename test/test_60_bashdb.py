'''Bashdb operation.'''

import pytest
import config


if "bashdb" not in config.BACKEND_NAMES:
    pytest.skip("skipping bashdb tests", allow_module_level=True)


def test_smoke(eng, post):
    '''Test a generic use case.'''
    assert post
    eng.feed(' db')
    eng.feed('\n', 1500)

    assert {'cur': 'main.sh:22'} == eng.get_signs()

    eng.feed('tbreak Main\n')
    eng.feed('<esc>')
    eng.feed('<f5>')
    assert {'cur': 'main.sh:16'} == eng.get_signs()

    eng.feed('<f10>')
    assert {'cur': 'main.sh:17'} == eng.get_signs()

    eng.feed('<f10>')
    assert {'cur': 'main.sh:18'} == eng.get_signs()

    eng.feed('<f11>')
    assert {'cur': 'main.sh:7'} == eng.get_signs()

    eng.feed('<c-p>', 200)
    assert {'cur': 'main.sh:18'} == eng.get_signs()

    eng.feed('<c-n>')
    assert {'cur': 'main.sh:7'} == eng.get_signs()

    eng.feed('<f12>', 200)
    assert {'cur': 'main.sh:17'} == eng.get_signs()

    eng.feed('<f5>')
    assert eng.wait_signs({}, 1500) is None


def test_break(eng, post, terminal_end):
    '''Test toggling breakpoints.'''
    assert post
    eng.feed(' db')
    eng.feed('\n', 1500)
    eng.feed('<esc>')

    eng.feed('<esc><c-w>k')
    eng.feed(':4<cr>')
    eng.feed('<f8>')
    assert {'cur': 'main.sh:22', 'break': {1: [4]}} == eng.get_signs()

    eng.exe('GdbContinue', 300)
    assert {'cur': 'main.sh:4', 'break': {1: [4]}} == eng.get_signs()

    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'main.sh:4'}) is None
