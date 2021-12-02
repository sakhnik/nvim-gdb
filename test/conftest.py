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
        'launch': ' dd a.out\n',
        'tbreak_main': 'tbreak main\n',
        'break_main': 'break main\n',
        'break_bar': 'break Bar\n',
        'launchF': ':GdbStart gdb -q {}\n',
        'watchF': 'watch {}\n',
    }
if "lldb" in config.BACKEND_NAMES:
    BACKENDS['lldb'] = {
        'name': 'lldb',
        'launch': ' dl a.out\n',
        'tbreak_main': 'breakpoint set -o true -n main\n',
        'break_main': 'breakpoint set -n main\n',
        'break_bar': 'breakpoint set --fullname Bar\n',
        'launchF': ':GdbStartLLDB lldb {}\n',
        'watchF': 'watchpoint set variable {}\n',
    }


@pytest.fixture(scope="function")
def terminal_end(eng):
    '''Check that the terminal last line is visible.'''
    yield True
    cursor_line = eng.exec_lua("return vim.api.nvim_win_get_cursor(NvimGdb.i().client.win)[1]")
    last_line = eng.exec_lua("return vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(NvimGdb.i().client.win))")
    win_height = eng.exec_lua("return vim.api.nvim_win_get_height(NvimGdb.i().client.win)")
    assert cursor_line >= last_line - win_height


@pytest.fixture(scope="function")
def post(eng, request):
    '''Prepare and check tabpages for every test.
       Quit debugging and do post checks.'''

    while eng.eval("tabpagenr('$')") > 1:
        eng.exe('tabclose $')
    num_bufs = eng.count_buffers()

    eng.logger.info("\n" + "=" * 80 + "\n")
    fname = os.path.basename(request.fspath)
    func = request.function.__qualname__
    eng.logger.info("Running %s::%s", fname, func)

    yield True

    eng.exe("GdbDebugStop")
    assert eng.eval("tabpagenr('$')") == 1
    assert {} == eng.get_signs()
    assert 0 == eng.count_termbuffers()
    # Check that no new buffers have left
    assert num_bufs == eng.count_buffers()

    for b in eng.nvim.buffers:
        if b.number == 1 or not eng.nvim.api.buf_is_loaded(b.handle):
            continue
        eng.nvim.command(f"bdelete! {b.number}")
        # api.buf_delete(b.handle, {'force': True})


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


@pytest.fixture(scope='function')
def config_test(eng, post):
    '''Fixture to clear custom keymaps.'''
    assert post
    yield True
    eng.exec_lua('''
for scope in ("bwtg"):gmatch'.' do
  for k, _ in pairs(NvimGdb.vim.fn.eval(scope .. ':')) do
    if type(k) == "string" and k:find('^nvimgdb_') then
      NvimGdb.vim.cmd('unlet ' .. scope .. ':' .. k)
    end
  end
end
                 ''')

@pytest.fixture(scope='function')
def cd_to_cmake(eng):
    eng.exe("cd src")
    eng.exe("e test.cpp")
    yield True
    eng.exe("bd")
    eng.exe("cd ..")
