#!/bin/bash -x

source .travis-common

curl -LO "$NVIM_RELEASE_URL/nvim.appimage"
chmod +x nvim.appimage
ln -sf "$PWD/nvim.appimage" /usr/local/bin/nvim

ln -sf /usr/bin/lldb-7.0 "$HOME/bin/lldb"
