#!/bin/bash -e

# Check the prerequisites
echo -n "Check for neovim     " && which nvim
echo -n "Check for python3    " && which python3
echo -n "Check for lua5.1     " && which lua5.1

source `dirname ${BASH_SOURCE[0]}`/env.sh

luarocks install busted --tree=$TREE
luarocks install nvim-client --tree=$TREE

echo "debuggers = {" >| config.py
echo -n "return {" >| config.lua

echo -n "Check for gdb        " && which gdb \
    && ( echo "'gdb': True," >> config.py;
         echo -n " ['gdb']=true," >> config.lua ) \
    || true
echo -n "Check for lldb       " && which lldb \
    && ( echo "'lldb': True," >> config.py;
         echo -n " ['lldb']=true," >> config.lua ) \
    || true
echo -e "'XXX': False\n}" >> config.py
echo -e " ['XXX']=false }" >> config.lua

CXX=g++
[[ `uname` == Darwin ]] && CXX=clang++

echo -n "Compiling test.cpp   "
if [[ src/test.cpp -nt a.out || src/lib.hpp -nt a.out ]]; then
    $CXX -g -std=c++11 src/test.cpp
    echo "a.out"
else
    echo "(cached a.out)"
fi

# Compile all moon scripts
find -name '*.moon' -exec moonc {} \;
