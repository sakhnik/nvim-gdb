from base_proxy import BaseProxy


class WinProxy(BaseProxy):
    def __init__(self, app_name: str):
        super().__init__(app_name)

    def write_master(self, data):
        """Write to the child process from its controlling terminal."""
        self.winproc.write(data.decode('utf-8'))

    def filter_changed(self, added: bool):
        """Don't care about filter here"""
