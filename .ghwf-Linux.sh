#!/bin/bash -xe

source .ghwf-common

curl -LO "$NVIM_RELEASE_URL/nvim.appimage"
chmod +x nvim.appimage
mkdir -p "$HOME/bin"
ln -sf "$PWD/nvim.appimage" "$HOME/bin/nvim"

# Make sure to install a recent version of LLDB
sudo bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"

sudo apt-get update
sudo apt-get install gdb cmake file --no-install-recommends

# Install bashdb
ver=$(curl -sL "https://sourceforge.net/projects/bashdb/rss" \
    | grep -oP '(?<=bashdb-)[0-9.-]+(?=\.tar\.bz2)' \
    | head -1)

wget -qc "https://sourceforge.net/projects/bashdb/files/bashdb/${ver}/bashdb-${ver}.tar.bz2"
tar -xvf bashdb-${ver}.tar.bz2
cd bashdb-${ver}
sed -e "/^\s\+'5.0' / s:): | '5.1'&:g" -i configure
./configure
make
sudo make install

command -v bashdb
