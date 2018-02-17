#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

if [[ $# -gt 0 ]]; then
    export NVIM_LISTEN_ADDRESS=/tmp/nvimtest
    nvim -n -u init.vim &
    python3 -m unittest
else
    python3 -m unittest -v
fi
