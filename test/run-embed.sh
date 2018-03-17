#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

# Run the test suite with embedded neovim
python3 $@
