#!/bin/bash -e

cd `dirname ${BASH_SOURCE[0]}`
this_dir=`pwd -P`   # Unfortunately, readlink -f isn't available in macos
rocks_tree="$this_dir/lua/rocks"

#luarocks=/usr/bin/luarocks-5.1
if [[ ! -x "$luarocks" ]]; then
    luarocks="$rocks_tree/bin/luarocks"
    if [[ ! -x "$luarocks" ]]; then
        cd /tmp

        vers=3.0.4
        wget -c http://luarocks.github.io/luarocks/releases/luarocks-$vers.tar.gz
        tar -xvf luarocks-$vers.tar.gz
        cd luarocks-$vers
        ./configure --prefix="$rocks_tree" --rocks-tree="$rocks_tree" --lua-version=5.1
        make bootstrap

        cd "$this_dir"
        rm -rf /tmp/luarocks-$vers*
    fi
fi

# Unfortunately, luaposix doesn't build when the luarocks loader
# is used. So let's comment it out in the LUA_INIT.
sed -i -f - $luarocks <<'EOF'
s|;\([^-][^;]*"luarocks.loader"[^']*'\)|;--[[\1]]|
EOF

cat >lua/set_paths.lua <<EOF
package.path = '`$luarocks path --lr-path`;' .. package.path
package.cpath = '`$luarocks path --lr-cpath`;' .. package.cpath
EOF

$luarocks install moonscript --tree="$rocks_tree"
$luarocks install luaposix --tree="$rocks_tree"
