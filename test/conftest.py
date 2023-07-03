'''Fixtures for tests.'''

# pylint: disable=redefined-outer-name

import pytest
import config
import os
import sys
from engine import Engine
import pynvim


@pytest.fixture(scope='session')
def eng():
    '''Create and supply nvim engine.'''
    engine = Engine()
    yield engine
    engine.close()


aout = "a.out" if sys.platform != 'win32' else 'a.exe'

BACKENDS = {}
if "gdb" in config.BACKEND_NAMES:
    BACKENDS['gdb'] = {
        'name': 'gdb',
        'launch': f' dd {aout}<cr>',
        'tbreak_main': 'tbreak main<cr>',
        'break_main': 'break main<cr>',
        'break_bar': 'break Bar<cr>',
        'launchF': ':GdbStart gdb -q {}<cr>',
        'watchF': 'watch {}<cr>',
    }
if "lldb" in config.BACKEND_NAMES:
    BACKENDS['lldb'] = {
        'name': 'lldb',
        'launch': f' dl {aout}<cr>',
        'tbreak_main': 'breakpoint set -o true -n main<cr>',
        'break_main': 'breakpoint set -n main<cr>',
        'break_bar': 'breakpoint set --fullname Bar<cr>',
        'launchF': ':GdbStartLLDB lldb {}<cr>',
        'watchF': 'watchpoint set variable {}<cr>',
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

    try:
        eng.exe("GdbDebugStop")
    except pynvim.api.common.NvimError:
        pass
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
  for k, _ in pairs(vim.fn.eval(scope .. ':')) do
    if type(k) == "string" and k:find('^nvimgdb_') then
      vim.api.nvim_command('unlet ' .. scope .. ':' .. k)
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


@pytest.fixture(scope='function')
def count_stops(eng):
    """Allow waiting for the specific count of debugger prompts appeared."""
    eng.exe("let g:prompt = 0")
    eng.exe("augroup pdbtest"
            " | au!"
            " | au! User NvimGdbQuery let g:prompt += 1"
            " | augroup END")

    class Prompt:
        def reset(self):
            eng.exe("let g:prompt = 0")

        def wait(self, count, deadline=2000):
            eng.wait_for(
                lambda: eng.eval("g:prompt"),
                lambda res: res >= count,
                deadline
            )
    yield Prompt()

    eng.exe("au! pdbtest | augroup! pdbtest")
    eng.exe("unlet g:prompt")
