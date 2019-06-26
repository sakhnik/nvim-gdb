import pytest
from config import config

if not "bashdb" in config:
    pytest.skip("skipping bashdb tests", allow_module_level=True)

def test_smoke(eng, post):
    # Test a generic use case.
    eng.feed(' db')
    eng.feed('\n', 1500)

    assert {'cur': 'main.sh:22'} == eng.getSigns()

    eng.feed('tbreak Main\n')
    eng.feed('<esc>')
    eng.feed('<f5>')
    assert {'cur': 'main.sh:16'} == eng.getSigns()

    eng.feed('<f10>')
    assert {'cur': 'main.sh:17'} == eng.getSigns()

    eng.feed('<f10>')
    assert {'cur': 'main.sh:18'} == eng.getSigns()

    eng.feed('<f11>')
    assert {'cur': 'main.sh:7'} == eng.getSigns()

    eng.feed('<c-p>', 200)
    assert {'cur': 'main.sh:18'} == eng.getSigns()

    eng.feed('<c-n>')
    assert {'cur': 'main.sh:7'} == eng.getSigns()

    eng.feed('<f12>', 200)
    assert {'cur': 'main.sh:17'} == eng.getSigns()

    eng.feed('<f5>')
    assert eng.waitSigns({}, 1500) is None

def test_break(eng, post):
    # Test toggling breakpoints.
    eng.feed(' db')
    eng.feed('\n', 1500)
    eng.feed('<esc>')

    eng.feed('<esc><c-w>k')
    eng.feed(':4<cr>')
    eng.feed('<f8>')
    assert {'cur': 'main.sh:22', 'break': {1: [4]}} == eng.getSigns()

    eng.exe('GdbContinue', 300)
    assert {'cur': 'main.sh:4', 'break': {1: [4]}} == eng.getSigns()

    eng.feed('<f8>')
    assert eng.waitSigns({'cur': 'main.sh:4'}) is None
