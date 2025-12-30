import sys

NVIM_RELEASE_URL = 'https://github.com/neovim/neovim/releases/download/v0.10.4'


if __name__ == "__main__":
    if sys.platform == "win32":
        from testenv_win32 import Setup
    elif sys.platform == "darwin":
        from testenv_darwin import Setup
    else:
        from testenv_linux import Setup
    Setup(NVIM_RELEASE_URL)
