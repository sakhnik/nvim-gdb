import os
import platform
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

        # Macos may be running on arm64
        machine = platform.machine()

        urllib.request.urlretrieve(f"{url}/nvim-macos-{machine}.tar.gz",
                                   f"nvim-macos-{machine}.tar.gz")
        subprocess.run(
            f'''
tar -xf nvim-macos-{machine}.tar.gz
cat >"$HOME/bin/nvim" <<EOF
#!/bin/bash
$(pwd)/nvim-macos-{machine}/bin/nvim "\\$@"
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
