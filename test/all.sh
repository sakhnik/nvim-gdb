#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`
python -m unittest -v
