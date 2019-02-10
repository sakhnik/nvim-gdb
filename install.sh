#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`
this_dir=`pwd -P`   # Unfortunately, readlink -f isn't available in macos
rocks_tree="$this_dir/lua/rocks"
luarocks="$rocks_tree/bin/luarocks"

if "$luarocks" --help >/dev/null 2>&1; then
    echo -n
else
    rm -rf "$rocks_tree"
    cd /tmp

    # Prefer luajit to lua51
    if which luajit >/dev/null 2>&1; then
        lua_interp="--with-lua-interpreter=luajit"
        lua_include="--with-lua-include=`pkg-config --cflags-only-I luajit | grep -Po '(?<=-I)[^\s]+'`"
    elif which lua51 >/dev/null 2>&1; then
        lua_interp="--with-lua-interpreter=lua5.1"
        lua_include="--with-lua-include=`pkg-config --cflags-only-I lua51 | grep -Po '(?<=-I)[^\s]+'`"
    else
        echo "!!! No luajit or lua51 detected, trying default lua"
    fi

    vers=3.0.4
    wget -c http://luarocks.github.io/luarocks/releases/luarocks-$vers.tar.gz
    tar -xvf luarocks-$vers.tar.gz
    cd luarocks-$vers
    ./configure --prefix="$rocks_tree" --rocks-tree="$rocks_tree" --lua-version=5.1 $lua_interp $lua_include
    make bootstrap

    cd "$this_dir"
    rm -rf /tmp/luarocks-$vers*
fi

$luarocks install luarocks --tree="$rocks_tree"

# Unfortunately, luaposix doesn't build when the luarocks loader
# is used. So let's comment it out in the LUA_INIT.
sed -i -e "s|;\\([^-][^;]*\"luarocks.loader\"[^']*'\\)|;--[[\\1]]|" $luarocks

$luarocks install luaposix --tree="$rocks_tree"
$luarocks install moonscript --tree="$rocks_tree"
