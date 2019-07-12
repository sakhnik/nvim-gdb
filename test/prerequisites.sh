#!/bin/bash -e

# Check the prerequisites
echo -n "Check for neovim     " && command -v nvim
echo -n "Check for python3    " && command -v python3

echo -n "" >| backends.txt

echo -n "Check for gdb        "
if command -v gdb; then
    echo "gdb" >> backends.txt
fi
echo -n "Check for lldb       "
if command -v lldb; then
    echo "lldb" >> backends.txt
fi
echo -n "Check for bashdb     "
if command -v bashdb; then
    echo "bashdb" >> backends.txt
fi

CXX=g++
[[ $(uname) == Darwin ]] && CXX=clang++

echo -n "Compiling test.cpp   "
if [[ src/test.cpp -nt a.out || src/lib.hpp -nt a.out ]]; then
    $CXX -g -std=c++11 src/test.cpp
    echo "a.out"
else
    echo "(cached a.out)"
fi

nvim --headless -u init.vim +UpdateRemotePlugins +qa
