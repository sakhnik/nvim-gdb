'''Fixtures for tests.'''

# pylint: disable=redefined-outer-name

import pytest
import config
import os
from engine import Engine


@pytest.fixture(scope='session')
def eng():
    '''Create and supply nvim engine.'''
    engine = Engine()
    yield engine
    engine.close()


BACKENDS = {}
if "gdb" in config.BACKEND_NAMES:
    BACKENDS['gdb'] = {
        'name': 'gdb',
        'launch': ' dd\n',
        'tbreak_main': 'tbreak main\n',
        'break_main': 'break main\n',
        'break_bar': 'break Bar\n',
        'launchF': ':GdbStart gdb -q {}\n',
    }
if "lldb" in config.BACKEND_NAMES:
    BACKENDS['lldb'] = {
        'name': 'lldb',
        'launch': ' dl\n',
        'tbreak_main': 'breakpoint set -o true -n main\n',
        'break_main': 'breakpoint set -n main\n',
        'break_bar': 'breakpoint set --fullname Bar\n',
        'launchF': ':GdbStartLLDB lldb {}\n',
    }


@pytest.fixture(scope="function")
def terminal_end(eng):
    '''Check that the terminal last line is visible.'''
    yield True
    cursor_line = eng.eval("GdbTestPeek('client', 'win', 'cursor')")[0]
    last_line = eng.eval("GdbTestPeek('client', 'win', 'buffer', 'api', "
                         "'line_count')")
    win_height = eng.eval("GdbTestPeek('client', 'win', 'height')")
    assert cursor_line >= last_line - win_height


@pytest.fixture(scope="function")
def post(eng, request):
    '''Prepare and check tabpages for every test.
       Quit debugging and do post checks.'''

    while eng.eval("tabpagenr('$')") > 1:
        eng.exe('tabclose $')
    num_bufs = eng.count_buffers()

    eng.log("\n")
    eng.log("=" * 80 + "\n")
    fname = os.path.basename(request.fspath)
    func = request.function.__qualname__
    eng.log(f"Running {fname}::{func}\n")
    eng.log("\n")

    yield True

    eng.exe("GdbDebugStop")
    assert eng.eval("tabpagenr('$')") == 1
    assert {} == eng.get_signs()
    assert 0 == eng.count_termbuffers()
    # Check that no new buffers have left
    assert num_bufs == eng.count_buffers()


@pytest.fixture(scope="function", params=BACKENDS.values())
def backend(post, request, terminal_end):
    '''Parametrized tests with C++ backends.'''
    assert post
    assert terminal_end
    yield request.param


@pytest.fixture(scope="function", params=BACKENDS.values())
def backend_express(post, request):
    '''Parametrized tests with C++ backends. Express.'''
    assert post
    yield request.param


@pytest.fixture(scope="function")
def two_backends(post):
    '''Use two C++ backends at once.'''
    assert post
    gdb = BACKENDS.get('gdb', None)
    lldb = BACKENDS.get('lldb', None)
    if gdb:
        yield gdb, lldb if lldb else gdb
    else:
        yield lldb, lldb
