#!/bin/bash -x

source .ghwf-common

mkdir -p "$HOME/bin"

pip install --user six

curl -LO $NVIM_RELEASE_URL/nvim-macos.tar.gz
tar -xf nvim-macos.tar.gz
cat >"$HOME/bin/nvim" <<EOF
#!/bin/bash
$(pwd)/nvim-osx64/bin/nvim "\$@"
EOF
chmod +x "$HOME/bin/nvim"

cat >"$HOME/bin/lldb" <<'EOF'
#!/bin/bash
PATH=/usr/bin /usr/bin/lldb "$@"
EOF
chmod +x "$HOME/bin/lldb"
