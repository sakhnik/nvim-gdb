'''Test various breakpoint operations.'''

import os
import tempfile
import pytest
import sys


def test_detect(eng, backend):
    '''Verify manual breakpoint is detected.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['break_main'])
    eng.feed('run<cr>')
    assert eng.wait_signs({'cur': 'test.cpp:17', 'break': {1: [17]}}) is None


# pylint: disable=redefined-outer-name

@pytest.fixture(scope='function')
def cd_tmp():
    '''Fixture to change directory temporarily.'''
    old_dir = os.path.realpath('.')
    os.chdir(tempfile.gettempdir())
    aout = 'a.out' if sys.platform != 'win32' else 'a.exe'
    yield os.path.join(old_dir, aout)
    os.chdir(old_dir)


def test_cd(eng, backend, cd_tmp):
    '''Verify manual breakpoint is detected from a random directory.'''
    eng.feed(backend['launchF'].format(cd_tmp))
    assert eng.wait_paused() is None
    eng.feed(backend['break_main'])
    eng.feed('run<cr>')
    assert eng.wait_signs({'cur': 'test.cpp:17', 'break': {1: [17]}}) is None


def test_navigate(eng, backend):
    '''Verify that breakpoints stay when source code is navigated.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['break_bar'])
    eng.feed("<esc>:wincmd w<cr>")
    eng.feed(":e src/test.cpp\n")
    eng.feed(":10<cr>")
    eng.feed("<f8>")

    assert eng.wait_signs({'break': {1: [5, 10]}}) is None

    # Go to another file
    eng.feed(":e src/lib.hpp\n")
    assert {} == eng.get_signs()
    eng.feed(":8\n")
    eng.feed("<f8>")
    assert eng.wait_signs({'break': {1: [8]}}) is None

    # Return to the first file
    eng.feed(":e src/test.cpp\n")
    assert eng.wait_signs({'break': {1: [5, 10]}}) is None


def test_clear_all(eng, backend):
    '''Verify that can clear all breakpoints.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['break_bar'])
    eng.feed(backend['break_main'])
    eng.feed("<esc>:wincmd w<cr>")
    eng.feed(":e src/test.cpp\n")
    eng.feed(":10<cr>")
    eng.feed("<f8>")

    assert eng.wait_signs({'break': {1: [5, 10, 17]}}) is None

    eng.feed(":GdbBreakpointClearAll\n")
    assert eng.wait_signs({}) is None


def test_duplicate(eng, backend):
    '''Verify that duplicate breakpoints are displayed distinctively.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['break_main'])
    eng.feed('run<cr>')
    assert eng.wait_signs({'cur': 'test.cpp:17', 'break': {1: [17]}}) is None
    eng.feed(backend['break_main'])
    assert eng.wait_signs({'cur': 'test.cpp:17', 'break': {2: [17]}}) is None
    eng.feed(backend['break_main'])
    assert eng.wait_signs({'cur': 'test.cpp:17', 'break': {3: [17]}}) is None
    eng.feed("<esc>:wincmd w<cr>")
    eng.feed(":17<cr>")
    eng.feed("<f8>")
    assert eng.wait_signs({'cur': 'test.cpp:17', 'break': {2: [17]}}) is None
    eng.feed("<f8>")
    assert eng.wait_signs({'cur': 'test.cpp:17', 'break': {1: [17]}}) is None
    eng.feed("<f8>")
    assert eng.wait_signs({'cur': 'test.cpp:17'}) is None


def test_watch(eng, backend):
    '''Verify that watchpoint transitions to paused.'''
    eng.feed(backend['launch'])
    assert eng.wait_paused() is None
    eng.feed(backend['break_main'])
    eng.feed('run<cr>')
    assert eng.wait_signs({'cur': 'test.cpp:17', 'break': {1: [17]}}) is None
    eng.feed(backend['watchF'].format('i'))
    eng.feed('cont<cr>')
    assert eng.wait_signs({'cur': 'test.cpp:17', 'break': {1: [17]}}) is None
