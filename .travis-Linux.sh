#!/bin/bash -x


ln -sf /usr/bin/python3.7 "$HOME/bin/python3"
ln -sf /usr/bin/python3.7-config "$HOME/bin/python3-config"

# Install pip for python3
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py --user

curl -LO https://github.com/neovim/neovim/releases/download/v0.3.4/nvim.appimage
chmod +x nvim.appimage
./nvim.appimage --appimage-extract

mkdir -p "$HOME/bin"
cat >"$HOME/bin/nvim" <<EOF
#!/bin/bash
$(pwd)/squashfs-root/usr/bin/nvim "\$@"
EOF
chmod +x "$HOME/bin/nvim"

ln -sf /usr/bin/lldb-7.0 "$HOME/bin/lldb"
