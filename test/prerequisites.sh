#!/bin/bash -e

# Check the prerequisites
echo -n "Check for neovim     " && which nvim
echo -n "Check for python3    " && which python3

echo -n "config = ['XXX'" >| config.py

echo -n "Check for gdb        "
if which gdb; then
    echo -n ", 'gdb'" >> config.py
fi
echo -n "Check for lldb       "
if which lldb; then
    echo -n ", 'lldb'" >> config.py
fi
echo -n "Check for bashdb     "
if which bashdb; then
    echo -n ", 'bashdb'" >> config.py
fi

echo ']' >> config.py

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
