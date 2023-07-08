import os
import re
import shutil
import subprocess
import urllib.request
import zipfile


class Setup:
    def __init__(self, url: str):
        urllib.request.urlretrieve(f"{url}/nvim-win64.zip", "nvim-win64.zip")
        with zipfile.ZipFile("nvim-win64.zip", 'r') as zip_ref:
            zip_ref.extractall("nvim")
        nvimbin = os.path.join(os.path.realpath("nvim"), "nvim-win64", "bin")
        with open(os.getenv("GITHUB_PATH"), 'a') as f:
            f.write(f'{nvimbin}\n')

        subprocess.run("choco install --no-progress -y msys2",
                       shell=True, check=True)
        subprocess.run('c:\\tools\\msys64\\usr\\bin\\pacman.exe -S --noconfirm'
                       ' mingw-w64-x86_64-gcc'
                       ' mingw-w64-x86_64-gdb'
                       ' mingw-w64-x86_64-lldb'
                       ' mingw-w64-x86_64-lua51',
                       shell=True, check=True)
        # c:\tools\msys64\mingw64\bin is appended to PATH in all.py
        # And we need it here too:
        current_path = os.environ['PATH']
        mingw_bin = r'c:\tools\msys64\mingw64\bin'
        os.environ['PATH'] = current_path + os.pathsep + mingw_bin

        luarocks_url = 'https://luarocks.github.io/luarocks/releases/'
        response = urllib.request.urlopen(luarocks_url)
        content = response.read().decode("utf-8")
        matches = re.findall(r'href="(.*windows-64)\.zip"', content)
        urllib.request.urlretrieve(f"{luarocks_url}{matches[0]}.zip",
                                   "luarocks.zip")
        with zipfile.ZipFile('luarocks.zip', 'r') as zip_ref:
            zip_ref.extractall("luarocks")
        shutil.move(f"luarocks/{matches[0]}/luarocks.exe", "luarocks/")

        subprocess.run([r'.\luarocks\luarocks.exe', '--lua-version=5.1',
                        'init'], check=True)
        subprocess.run([r'.\luarocks\luarocks.exe', '--lua-version=5.1',
                        'install', 'busted'], check=True)
