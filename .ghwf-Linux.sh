#!/bin/bash -x

source .travis-common

curl -LO "$NVIM_RELEASE_URL/nvim.appimage"
chmod +x nvim.appimage
mkdir -p "$HOME/bin"
ln -sf "$PWD/nvim.appimage" "$HOME/bin/nvim"
ln -sf /usr/bin/lldb-7.0 "$HOME/bin/lldb"
