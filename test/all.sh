#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`
NVIM_LISTEN_ADDRESS=/tmp/nvimtest nvim -n -u init.vim &
python3 -m unittest -v
