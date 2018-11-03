#!/bin/bash -e

this_dir=$(readlink -f `dirname ${BASH_SOURCE[0]}`)
rocks_tree="$this_dir/lua/rocks"
cd "$this_dir"

luarocks=/usr/bin/luarocks-5.1

#if [[ ! -x "$rocks_tree/bin/luarocks" ]]; then
#    cd /tmp
#
#    vers=3.0.4
#    wget -c http://luarocks.github.io/luarocks/releases/luarocks-$vers.tar.gz
#    tar -xvf luarocks-$vers.tar.gz
#    cd luarocks-$vers
#    ./configure --prefix="$rocks_tree" --rocks-tree="$rocks_tree" --lua-version=5.1 --lua-suffix=-5.1
#    make bootstrap
#
#    cd "$this_dir"
#    rm -rf /tmp/luarocks-$vers*
#fi

$luarocks install luaposix --tree="$rocks_tree"
