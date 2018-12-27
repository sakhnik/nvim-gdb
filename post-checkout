#!/bin/bash

moonc=lua/rocks/bin/moonc
if [[ -x $moonc ]]; then
    find lua/gdb -name '*.moon' -exec $moonc {} \;
fi
