import os
import subprocess
import urllib.request


class Setup:
    def __init__(self, url: str):
        bindir = os.path.join(os.getenv('HOME'), 'bin')
        subprocess.run(f'mkdir -p {bindir}', shell=True, check=True)
        github_path = os.getenv("GITHUB_PATH")
        if github_path:
            with open(github_path, 'a') as f:
                f.write(f'{bindir}\n')
        else:
            print(f"Ensure {bindir} is in PATH")

        subprocess.run('pip install --user six', shell=True, check=True)

        urllib.request.urlretrieve(f"{url}/nvim-macos.tar.gz",
                                   "nvim-macos.tar.gz")
        subprocess.run(
            r'''
tar -xf nvim-macos.tar.gz
cat >"$HOME/bin/nvim" <<EOF
#!/bin/bash
$(pwd)/nvim-macos/bin/nvim "\$@"
EOF
chmod +x "$HOME/bin/nvim"
            ''',
            shell=True, check=True
        )

        subprocess.run(
            r'''
cat >"$HOME/bin/lldb" <<'EOF'
#!/bin/bash
PATH=/usr/bin /usr/bin/lldb "$@"
EOF
chmod +x "$HOME/bin/lldb"
            ''',
            shell=True, check=True
        )

        subprocess.run(
            r'''
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install luarocks luajit
luarocks --lua-version=5.1 init
luarocks --lua-version=5.1 install busted
            ''',
            shell=True, check=True
        )
