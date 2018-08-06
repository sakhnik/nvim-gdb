#!/bin/bash -e

# Check the prerequisites
echo -n "Check for neovim     " && which nvim
echo -n "Check for python3    " && which python3

echo "debuggers = {">| config.py

echo -n "Check for gdb        " && which gdb && echo "'gdb': True," >> config.py || true
echo -n "Check for lldb       " && which lldb && echo "'lldb': True," >> config.py || true
echo -e "'XXX': False\n}" >> config.py

CXX=g++
[[ `uname` == Darwin ]] && CXX=clang++

echo -n "Compiling test.cpp   "
if [[ src/test.cpp -nt a.out || src/lib.hpp -nt a.out ]]; then
    $CXX -g -std=c++11 src/test.cpp
    echo "a.out"
else
    echo "(cached a.out)"
fi
