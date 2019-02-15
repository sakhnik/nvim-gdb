#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

./prerequisites.sh

python3 ../lib/StreamFilter.py

if [[ $# -gt 0 ]]; then
    ./run-visual -vv test_40_keymap.py::test_conflict
else
    ./run -vv
fi
