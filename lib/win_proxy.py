from base_proxy import BaseProxy


class WinProxy(BaseProxy):
    def __init__(self, app_name: str):
        super().__init__(app_name)
