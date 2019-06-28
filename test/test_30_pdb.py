'''Test PDB support.'''

import os
import sys


def test_smoke(eng, post):
    '''Test a generic use case.'''
    eng.feed(' dp')
    eng.feed('\n', 300)
    eng.feed('tbreak _main\n')
    eng.feed('cont\n')
    eng.feed('<esc>')

    assert {'cur': 'main.py:15'} == eng.get_signs()

    eng.feed('<f10>')
    assert {'cur': 'main.py:16'} == eng.get_signs()

    eng.feed('<f11>')
    assert {'cur': 'main.py:8'} == eng.get_signs()

    eng.feed('<c-p>')
    assert {'cur': 'main.py:16'} == eng.get_signs()

    eng.feed('<c-n>')
    assert {'cur': 'main.py:8'} == eng.get_signs()

    eng.feed('<f12>')
    assert {'cur': 'main.py:10'} == eng.get_signs()

    eng.feed('<f5>')
    assert eng.wait_signs({'cur': 'main.py:1'}, 1500) is None


def test_break(eng, post):
    '''Test toggling breakpoints.'''
    eng.feed(' dp')
    eng.feed('\n', 300)
    eng.feed('<esc>')

    eng.feed('<esc><c-w>k')
    eng.feed(':5<cr>')
    eng.feed('<f8>')
    assert {'cur': 'main.py:1', 'break': {1: [5]}} == eng.get_signs()

    eng.exe('GdbContinue')
    assert {'cur': 'main.py:5', 'break': {1: [5]}} == eng.get_signs()

    eng.feed('<f8>')
    assert eng.wait_signs({'cur': 'main.py:5'}) is None


def test_navigation(eng, post):
    '''Test toggling breakpoints while navigating.'''
    eng.feed(' dp')
    eng.feed('\n', 300)
    eng.feed('<esc>')

    eng.feed('<esc><c-w>w')
    eng.feed(':5<cr>')
    eng.feed('<f8>')
    assert {'cur': 'main.py:1', 'break': {1: [5]}} == eng.get_signs()

    # Go to another file
    eng.feed(':e lib.py\n')
    eng.feed(':3\n')
    eng.feed('<f8>')
    assert {'cur': 'main.py:1', 'break': {1: [3]}} == eng.get_signs()
    eng.feed(':5\n')
    eng.feed('<f8>')
    assert {'cur': 'main.py:1', 'break': {1: [3, 5]}} == eng.get_signs()

    # Return to the original file
    eng.feed(':e main.py\n')
    assert {'cur': 'main.py:1', 'break': {1: [5]}} == eng.get_signs()


def test_until(eng, post):
    '''Test run until line.'''
    eng.feed(' dp')
    eng.feed('\n', 300)
    eng.feed('tbreak _main\n')
    eng.feed('cont\n')
    eng.feed('<esc>')

    eng.feed('<c-w>w')
    eng.feed(':18<cr>')
    eng.feed('<f4>')

    signs = eng.get_signs()
    # Python started supporting 'until line' since some version.
    # And the test still doesn't work on Travis on Darwin.
    assert len(signs) == 1
    if sys.version_info >= (3, 6) and not os.getenv("TRAVIS_BUILD_ID"):
        assert signs['cur'] == 'main.py:18'
    else:
        assert signs['cur']


def test_eval(eng, post):
    '''Test eval <word>.'''
    eng.feed(' dp')
    eng.feed('\n', 300)
    eng.feed('tbreak _main\n')
    eng.feed('cont\n')
    eng.feed('<esc>')
    eng.feed('<c-w>w')
    eng.feed('<f10>')

    eng.feed('^<f9>')
    assert eng.eval('GdbTestPeek("lastCommand")') == 'print(_Foo)'

    eng.feed('viW')
    eng.feed(':GdbEvalRange\n')
    assert eng.eval('GdbTestPeek("lastCommand")') == 'print(_Foo(i))'
