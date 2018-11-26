#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

cleanup_action="echo 'cleanup'"

add_cleanup_action() {
    cleanup_action="$cleanup_action; $@"
}

cleanup() {
    eval "$cleanup_action"
}

trap cleanup EXIT

export NVIM_LISTEN_ADDRESS=/tmp/nvimtest
rm -rf $NVIM_LISTEN_ADDRESS

# Run the test suite with a visible neovim
LANG=en_US.UTF-8 nvim --listen $NVIM_LISTEN_ADDRESS -n -u init.vim &
add_cleanup_action "kill -KILL `jobs -p`; wait; reset"

python3 $@
