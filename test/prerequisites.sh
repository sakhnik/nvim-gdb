#!/bin/bash -e

# Check the prerequisites
echo -n "Check for neovim     " && which nvim
echo -n "Check for gdb        " && which gdb
echo -n "Check for lldb       " && which lldb
echo -n "Check for python3    " && which python3

echo -n "Compiling test.cpp   "
if [[ src/test.cpp -nt a.out || src/lib.hpp -nt a.out ]]; then
    g++ -g -std=c++11 src/test.cpp
    echo "a.out"
else
    echo "(cached a.out)"
fi
