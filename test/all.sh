#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

./prerequisites.sh

if [[ $# -gt 0 ]]; then
    ./run-visual.sh -m unittest
else
    ./run-embed.sh -m unittest -v
fi
