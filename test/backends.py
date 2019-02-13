import config

class Backends:
    def __init__(self):
        self.backends = {}
        if "gdb" in config.config:
            self.backends["gdb"] = {
                'launch': ' dd\n',
                'tbreak_main': 'tbreak main\n',
                'break_main': 'break main\n',
                'break_bar': 'break Bar\n'
            }
        if "lldb" in config.config:
            self.backends["lldb"] = {
                'launch': ' dl\n',
                'tbreak_main': 'breakpoint set -o true -n main\n',
                'break_main': 'breakpoint set -n main\n',
                'break_bar': 'breakpoint set --fullname Bar\n'
            }

    def get(self):
        return self.backends
