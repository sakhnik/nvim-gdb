#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`
python3 -m unittest -v
