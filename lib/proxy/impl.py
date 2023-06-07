import sys

if sys.platform != 'win32':
    from .impl_unix import ImplUnix
    Impl = ImplUnix
else:
    from .impl_win import ImplWin
    Impl = ImplWin
