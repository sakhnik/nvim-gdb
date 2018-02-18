#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

# Check the prerequisits
echo -n "Check for neovim   " && which nvim
echo -n "Check for gdb      " && which gdb
echo -n "Check for lldb     " && which lldb
echo -n "Check for python3  " && which python3

cleanup_action="echo 'cleanup'"

add_cleanup_action() {
    cleanup_action="$cleanup_action; $@"
}

cleanup() {
    eval "$cleanup_action"
}

trap cleanup EXIT

if [[ $# -gt 0 ]]; then
    export NVIM_LISTEN_ADDRESS=/tmp/nvimtest
    rm -rf $NVIM_LISTEN_ADDRESS

    # Run the test suite with a visible neovim
    nvim -n -u init.vim &
    add_cleanup_action "kill -KILL `jobs -p`; wait; reset"

    python3 -m unittest
else
    # Run the test suite with embedded neovim
    python3 -m unittest -v
fi
