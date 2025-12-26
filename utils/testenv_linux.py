import os
import subprocess
import urllib.request


class Setup:
    def __init__(self, url: str):
        urllib.request.urlretrieve(f"{url}/nvim-linux-x86_64.appimage", "nvim.appimage")
        os.chmod("nvim.appimage", 0o755)
        bindir = os.path.join(os.getenv('HOME'), 'bin')
        os.mkdir(bindir)
        os.symlink(os.path.realpath("nvim.appimage"),
                   os.path.join(bindir, "nvim"))

        with open(os.getenv("GITHUB_PATH"), 'a') as f:
            f.write(f'{bindir}\n')

        subprocess.run(
            r'''
sudo apt-get update
sudo apt-get install libfuse2 gdb lldb python3-lldb-14 cmake file --no-install-recommends
# Fix lldb python path mismatch
sudo mkdir -p /usr/lib/local/lib/python3.10
sudo ln -s /usr/lib/llvm-14/lib/python3.10/dist-packages /usr/lib/local/lib/python3.10/dist-packages
            ''',
            shell=True, check=True
        )

        subprocess.run(
            r'''
# Install bashdb
ver=$(curl -sL "https://sourceforge.net/projects/bashdb/rss" \
    | grep -oP '(?<=bashdb-)[0-9.-]+(?=\.tar\.bz2)' \
    | head -1)
bashdb_url="https://sourceforge.net/projects/bashdb/files/bashdb"
wget -qc "$bashdb_url/${ver}/bashdb-${ver}.tar.bz2"
tar -xvf bashdb-${ver}.tar.bz2
cd bashdb-${ver}
sed -e "/^\s\+'5.0' / s:): | '5.1'&:g" -i configure
./configure
make
sudo make install

command -v bashdb
            ''',
            shell=True, check=True
        )

        subprocess.run(
            r'''
sudo apt-get install luarocks luajit
luarocks --lua-version=5.1 init
luarocks --lua-version=5.1 install busted
            ''',
            shell=True, check=True
        )
