#!/bin/bash -x

brew install neovim
sudo pip install six
cat >/usr/local/bin/lldb <<'EOF'
#!/bin/bash
PATH=/usr/bin /usr/bin/lldb "$@"
EOF
chmod +x /usr/local/bin/lldb
