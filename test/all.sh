#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

# Check the prerequisits
echo -n "Check for neovim   " && which nvim
echo -n "Check for gdb      " && which gdb
echo -n "Check for lldb     " && which lldb
echo -n "Check for python3  " && which python3

if [[ $# -gt 0 ]]; then
    export NVIM_LISTEN_ADDRESS=/tmp/nvimtest

    # Run the test suite with a visible neovim
    nvim -n -u init.vim &
    python3 -m unittest

    # Cleanup the terminal
    kill -KILL %1
    wait
    reset
else
    # Run the test suite with embedded neovim
    python3 -m unittest -v
fi
