import os
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
                       ' mingw-w64-x86_64-lldb',
                       shell=True, check=True)
        # c:\tools\msys64\mingw64\bin is appended to PATH in all.py
