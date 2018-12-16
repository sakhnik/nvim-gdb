config = require "config"

backends = {}
if config.gdb != nil
    backends.gdb = {'launch': ' dd\n',
                    'tbreak_main': 'tbreak main\n',
                    'break_main': 'break main\n',
                    'break_bar': 'break Bar\n'}
if config.lldb != nil
    backends.lldb = {'launch': ' dl\n',
                     'tbreak_main': 'breakpoint set -o true -n main\n',
                     'break_main': 'breakpoint set -n main\n',
                     'break_bar': 'breakpoint set --fullname Bar\n'}

backends
