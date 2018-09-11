#!/bin/bash -x

brew install neovim

pip install --user six

mkdir -p $HOME/bin
cat >$HOME/bin/lldb <<'EOF'
#!/bin/bash
PATH=/usr/bin /usr/bin/lldb "$@"
EOF
chmod +x $HOME/bin/lldb
