#!/bin/bash -x

mkdir -p $HOME/bin

pip install --user six

curl -LO https://github.com/neovim/neovim/releases/download/v0.3.1/nvim-macos.tar.gz
tar -xf nvim-macos.tar.gz
cat >$HOME/bin/nvim <<EOF
#!/bin/bash
`pwd`/nvim-osx64/bin/nvim "\$@"
EOF
chmod +x $HOME/bin/nvim

cat >$HOME/bin/lldb <<'EOF'
#!/bin/bash
PATH=/usr/bin /usr/bin/lldb "$@"
EOF
chmod +x $HOME/bin/lldb
