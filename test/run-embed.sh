#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`

# Run the test suite with embedded neovim
LANG=en_US.UTF-8 python3 $@
