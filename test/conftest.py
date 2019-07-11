'''Fixtures for tests.'''

# pylint: disable=redefined-outer-name

import pytest
import config
from engine import Engine


@pytest.fixture(scope='session')
def eng():
    '''Create and supply nvim engine.'''
    engine = Engine()
    yield engine
    engine.close()


BACKENDS = {}
if "gdb" in config.config:
    BACKENDS['gdb'] = {
        'name': 'gdb',
        'launch': ' dd\n',
        'tbreak_main': 'tbreak main\n',
        'break_main': 'break main\n',
        'break_bar': 'break Bar\n',
        'launchF': ':GdbStart gdb -q {}\n',
    }
if "lldb" in config.config:
    BACKENDS['lldb'] = {
        'name': 'lldb',
        'launch': ' dl\n',
        'tbreak_main': 'breakpoint set -o true -n main\n',
        'break_main': 'breakpoint set -n main\n',
        'break_bar': 'breakpoint set --fullname Bar\n',
        'launchF': ':GdbStartLLDB lldb {}\n',
    }


@pytest.fixture(scope="function")
def post(eng):
    '''Prepare and check tabpages for every test.
       Quit debugging and do post checks.'''
    while eng.eval("tabpagenr('$')") > 1:
        eng.exe('tabclose $')
    yield True
    eng.exe("GdbDebugStop")
    assert eng.eval("tabpagenr('$')") == 1
    assert {} == eng.get_signs()


@pytest.fixture(scope="function", params=BACKENDS.values())
def backend(post, request):
    '''Parametrized tests with C++ backends.'''
    assert post
    yield request.param


@pytest.fixture(scope="function")
def two_backends(post):
    '''Use two C++ backends at once.'''
    assert post
    it1 = iter(BACKENDS.values())
    backend1 = next(it1, None)
    backend2 = next(it1, backend1)
    yield backend1, backend2
