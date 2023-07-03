'''Bashdb operation.'''

import pytest
import config


if "bashdb" not in config.BACKEND_NAMES:
    pytest.skip("skipping bashdb tests", allow_module_level=True)


def test_smoke(eng, post, count_stops):
    '''Test a generic use case.'''
    assert post
    eng.feed(' db\n')
    assert count_stops.wait(1) is None
    assert eng.wait_signs({'cur': 'main.sh:22'}) is None

    eng.feed('tbreak Main\n')
    eng.feed('<esc>')
    eng.feed('<f5>')
    assert eng.wait_signs({'cur': 'main.sh:16'}) is None

    eng.feed('<f10>')
    assert eng.wait_signs({'cur': 'main.sh:17'}) is None

    eng.feed('<f10>')
    assert eng.wait_signs({'cur': 'main.sh:18'}) is None

    eng.feed('<f11>')
    assert eng.wait_signs({'cur': 'main.sh:7'}) is None

    eng.feed('<c-p>', 300)
    assert eng.wait_signs({'cur': 'main.sh:18'}) is None

    eng.feed('<c-n>')
    assert eng.wait_signs({'cur': 'main.sh:7'}) is None

    eng.feed('<f12>', 200)
    assert eng.wait_signs({'cur': 'main.sh:17'}) is None

    eng.feed('<f5>')
    assert eng.wait_signs({}) is None


def test_break(eng, post, count_stops):
    '''Test toggling breakpoints.'''
    assert post
    eng.feed(' db\n')
    assert count_stops.wait(1) is None
    eng.feed('<esc>')

    eng.feed('<esc><c-w>k')
    eng.feed(':4<cr>')
    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'main.sh:22', 'break': {1: [4]}}) is None

    eng.exe('GdbContinue', 300)
    assert eng.wait_signs({'cur': 'main.sh:4', 'break': {1: [4]}}) is None

    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'main.sh:4'}) is None


def test_repeat_last_command(eng, post, count_stops):
    '''Test last command is repeated on empty input.'''
    assert post
    eng.feed(' db\n')
    assert count_stops.wait(1) is None
    assert eng.wait_signs({'cur': 'main.sh:22'}) is None

    eng.feed('tbreak Main\n')
    eng.feed('cont\n')
    assert eng.wait_signs({'cur': 'main.sh:16'}) is None

    eng.feed('n\n')
    assert eng.wait_signs({'cur': 'main.sh:17'}) is None
    eng.feed('<cr>')
    assert eng.wait_signs({'cur': 'main.sh:18'}) is None
    eng.feed('<cr>')
    assert eng.wait_signs({'cur': 'main.sh:17'}) is None
