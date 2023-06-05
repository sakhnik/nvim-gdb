from unix_proxy import UnixProxy
from win_proxy import WinProxy
import sys

ProxyImpl = UnixProxy if sys.platform != 'win32' else WinProxy
