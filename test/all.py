#!/usr/bin/env python3

import os
import subprocess
import sys
import tempfile


# It seems to be impossible to insert into PATH in GitHub Actions for now.
# Let's allow accessing gdb in the scope of the process.
if sys.platform == 'win32' and os.getenv('GITHUB_WORKFLOW'):
    path = os.environ["PATH"].split(';')
    # Hopefully after Python
    path = path[:10] + ["C:\\tools\\msys64\\mingw64\\bin"] + path[10:]
    os.environ["PATH"] = ";".join(path)

os.chdir(os.path.join(os.path.dirname(__file__), '..'))
root_dir = os.getcwd()

# Deliberately test that the tests pass from a random symlink
# to the source directory.
with tempfile.TemporaryDirectory() as tmp_dir:
    if sys.platform != 'win32':
        os.symlink(root_dir, os.path.join(tmp_dir, 'src'),
                   target_is_directory=True)
        os.chdir(os.path.join(tmp_dir, 'src', 'test'))
    else:
        os.chdir(os.path.join(root_dir, "test"))

    print("Test neovim is usable")
    res = subprocess.run(["nvim", "--headless", "+qa"])
    if res.returncode != 0:
        raise RuntimeError("Neovim check failed")

    from prerequisites import Prerequisites
    Prerequisites()

    res = subprocess.run(["nvim", "-l", "run-tests.lua"])
    if res.returncode != 0:
        raise RuntimeError("Lua tests failed")

    import pytest
    pytest.main(['..', '-vv'])
