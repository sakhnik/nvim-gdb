#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

./prerequisites.sh

python3 ../lib/StreamFilter.py

export PATH=../lua/rocks/bin:$PATH

if [[ $# -gt 0 ]]; then
    ./run-visual.sh .
else
    ./busted .
fi
