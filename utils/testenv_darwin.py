import os
import subprocess
import urllib.request


class Setup:
    def __init__(self, url: str):
        bindir = os.path.join(os.getenv('HOME'), 'bin')
        subprocess.run(f'mkdir -p {bindir}', shell=True, check=True)
        with open(os.getenv("GITHUB_PATH"), 'a') as f:
            f.write(f'{bindir}\n')

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
