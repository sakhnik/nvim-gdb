#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

./prerequisites.sh

python3 ../lib/StreamFilter.py

export PATH=../lua/rocks/bin:$PATH

for i in *_spec.moon; do
    echo "Running $i"
    busted $i
done
