import pytest
import config
from engine import Engine


@pytest.fixture(scope='session')
def eng():
    eng = Engine()
    yield eng
    eng.close()

backends = {}
if "gdb" in config.config:
    backends['gdb'] = {
        'name': 'gdb',
        'launch': ' dd\n',
        'tbreak_main': 'tbreak main\n',
        'break_main': 'break main\n',
        'break_bar': 'break Bar\n',
        'launchF': ':GdbStart gdb -q {}\n',
    }
if "lldb" in config.config:
    backends['lldb'] = {
        'name': 'lldb',
        'launch': ' dl\n',
        'tbreak_main': 'breakpoint set -o true -n main\n',
        'break_main': 'breakpoint set -n main\n',
        'break_bar': 'breakpoint set --fullname Bar\n',
        'launchF': ':GdbStartLLDB lldb {}\n',
    }

@pytest.fixture(scope="function")
def post(eng):
    while eng.eval("tabpagenr('$')") > 1:
        eng.exe('tabclose $')
    yield
    eng.exe("GdbDebugStop")
    assert 1 == eng.eval("tabpagenr('$')")
    assert {} == eng.getSigns()

@pytest.fixture(scope="function", params=backends.values())
def backend(post, request):
    yield request.param

@pytest.fixture(scope="function")
def two_backends(post):
    it = iter(backends.values())
    b1 = next(it)
    b2 = next(it, b1)
    yield b1, b2
