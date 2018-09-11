#!/bin/bash -x

curl -LO https://github.com/neovim/neovim/releases/download/v0.3.1/nvim.appimage
chmod +x nvim.appimage
./nvim.appimage --appimage-extract

mkdir -p $HOME/bin
cat >$HOME/bin/nvim <<EOF
#!/bin/bash
`pwd`/squashfs-root/usr/bin/nvim "\$@"
EOF
chmod +x $HOME/bin/nvim

ln -sf /usr/bin/lldb-5.0 $HOME/bin/lldb
