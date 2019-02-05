#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

./prerequisites.sh
nvim -u init.vim +UpdateRemotePlugins +qa

python3 ../lib/StreamFilter.py

if [[ $# -gt 0 ]]; then
    ./busted-visual .
else
    ./busted .
fi
