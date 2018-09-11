#!/bin/bash -x

wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -
echo "deb http://apt.llvm.org/trusty/ llvm-toolchain-trusty-5.0 main" | sudo tee -a /etc/apt/sources.list
sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
sudo apt-get -qq update
sudo apt-get install -y g++ gdb lldb-5.0
sudo apt-get install python3-dev python3-pip
sudo ln -sf /usr/bin/lldb-5.0 /usr/bin/lldb

curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
chmod +x nvim.appimage
./nvim.appimage --appimage-extract

mkdir -p $HOME/bin
cat >$HOME/bin/nvim <<EOF
#!/bin/bash
`pwd`/squashfs-root/usr/bin/nvim "\$@"
EOF
chmod +x $HOME/bin/nvim
