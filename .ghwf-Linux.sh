#!/bin/bash -x

source .travis-common

curl -LO "$NVIM_RELEASE_URL/nvim.appimage"
chmod +x nvim.appimage
./nvim.appimage --appimage-extract

mkdir -p "$HOME/bin"
cat >"$HOME/bin/nvim" <<EOF
#!/bin/bash
$(pwd)/squashfs-root/usr/bin/nvim "\$@"
EOF
chmod +x "$HOME/bin/nvim"

ln -sf /usr/bin/lldb-7.0 "$HOME/bin/lldb"
