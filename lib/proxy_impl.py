import sys

if sys.platform != 'win32':
    from unix_proxy import UnixProxy
    ProxyImpl = UnixProxy
else:
    from win_proxy import WinProxy
    ProxyImpl = WinProxy
