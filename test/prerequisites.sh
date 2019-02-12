#!/bin/bash -e

# Check the prerequisites
echo -n "Check for neovim     " && which nvim
echo -n "Check for python3    " && which python3
echo -n "Check for luajit     " && which luajit || {
echo -n "Check for lua5.1     " && which lua5.1
}

this_dir=`dirname ${BASH_SOURCE[0]}`

eval `$this_dir/../lua/rocks/bin/luarocks path`

LUAROCKS_TREE=$this_dir/../lua/rocks
luarocks install busted --tree=$LUAROCKS_TREE
luarocks install nvim-client --tree=$LUAROCKS_TREE

echo -n "return {" >| config.lua

echo -n "Check for gdb        " && which gdb \
    && echo -n " ['gdb']=true," >> config.lua \
    || true
echo -n "Check for lldb       " && which lldb \
    && echo -n " ['lldb']=true," >> config.lua \
    || true
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

nvim -u init.vim +UpdateRemotePlugins +qa

# Compile all moon scripts
moonc engine.moon backends.moon
