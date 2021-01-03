#!/bin/bash -x

source .travis-common

curl -LO "$NVIM_RELEASE_URL/nvim.appimage"
chmod +x nvim.appimage
mkdir -p "$HOME/bin"
ln -sf "$PWD/nvim.appimage" "$HOME/bin/nvim"

sudo apt-get update
sudo apt-get install gdb lldb

bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
homebrew install bashdb
