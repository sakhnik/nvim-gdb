#!/usr/bin/env python3

import os
import subprocess
import tempfile


os.chdir(os.path.join(os.path.dirname(__file__), '..'))
root_dir = os.getcwd()

# Deliberately test that the tests pass from a random symlink
# to the source directory.
with tempfile.TemporaryDirectory() as tmp_dir:
    os.symlink(root_dir, os.path.join(tmp_dir, 'src'),
               target_is_directory=True)

    os.chdir(os.path.join(tmp_dir, 'src', 'test'))

    print("Test neovim is usable")
    res = subprocess.run(["nvim", "--headless", "+qa"])
    if res.returncode != 0:
        raise RuntimeError("Neovim check failed")

    from prerequisites import Prerequisites
    Prerequisites()

    import pytest
    pytest.main(['..', '-vv'])
