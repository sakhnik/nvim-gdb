#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`


export NVIM_LISTEN_ADDRESS=127.0.0.1:12345

# Run the test suite with a visible neovim
LANG=en_US.UTF-8 nvim -n -u init.vim --listen $NVIM_LISTEN_ADDRESS &

cleanup()
{
    kill -KILL `jobs -p`
    wait
    reset
}
trap cleanup EXIT

busted $@ >visual.log 2>&1
