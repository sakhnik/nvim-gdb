import pytest
import config
from engine import Engine


@pytest.fixture(scope='session')
def eng():
    eng = Engine()
    yield eng
    eng.close()

backends = []
if "gdb" in config.config:
    backends.append({
        'launch': ' dd\n',
        'tbreak_main': 'tbreak main\n',
        'break_main': 'break main\n',
        'break_bar': 'break Bar\n'
    })
if "lldb" in config.config:
    backends.append({
        'launch': ' dl\n',
        'tbreak_main': 'breakpoint set -o true -n main\n',
        'break_main': 'breakpoint set -n main\n',
        'break_bar': 'breakpoint set --fullname Bar\n'
    })

@pytest.fixture(scope="function", params=backends)
def backend(eng, request):
    yield request.param
    eng.exe("GdbDebugStop")
    assert 1 == eng.eval("tabpagenr('$')")
    assert {} == eng.getSigns()

@pytest.fixture(scope="function")
def two_backends(eng):
    b1 = backends[0]
    b2 = backends[0 if len(backends) == 1 else 1]
    yield b1, b2
    eng.exe("GdbDebugStop")
    assert 1 == eng.eval("tabpagenr('$')")
    assert {} == eng.getSigns()
