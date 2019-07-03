'''.'''

import json
from gdb.common import Common


class Breakpoint(Common):
    '''Handle breakpoint signs.'''
    def __init__(self, common, config, proxy):
        super().__init__(common)
        self.config = config
        self.proxy = proxy
        self.breaks = {}    # {file -> {line -> [id]}}
        self.max_sign_id = 0

    def clear_signs(self):
        '''Clear all breakpoint signs.'''
        for i in range(5000, self.max_sign_id + 1):
            self.vim.command(f'sign unplace {i}')
        self.max_sign_id = 0

    def _set_signs(self, buf):
        if buf != -1:
            sign_id = 5000 - 1
            # Breakpoints need full path to the buffer (at least in lldb)
            bpath = self.vim.call("expand", f'#{buf}:p')

            def get_sign_name(count):
                max_count = len(self.config['sign_breakpoint'])
                idx = count if count < max_count else max_count - 1
                return f"GdbBreakpoint{idx}"

            for line, ids in self.breaks.get(bpath, {}).items():
                sign_id += 1
                sign_name = get_sign_name(len(ids))
                cmd = f'sign place {sign_id} name={sign_name} line={line}' \
                      f' buffer={buf}'
                self.vim.command(cmd)
            self.max_sign_id = sign_id

    def query(self, buf_num, fname):
        '''Query actual breakpoints for the given file.'''
        self.breaks[fname] = {}
        resp = self.proxy.query(f"info-breakpoints {fname}\n")
        if resp:
            # We expect the proxies to send breakpoints for a given file
            # as a map of lines to array of breakpoint ids set in those lines.
            breaks = json.loads(resp)
            err = breaks.get('_error', None)
            if err:
                self.vim.command(f"echo \"Can't get breakpoints: {err}\"")
            else:
                self.breaks[fname] = breaks
                self.clear_signs()
                self._set_signs(buf_num)

    def reset_signs(self):
        '''Reset all known breakpoints and their signs.'''
        self.breaks = {}
        self.clear_signs()

    def get_for_file(self, fname, line):
        '''Get breakpoints for the given position in a file.'''
        breaks = self.breaks.get(fname, {})
        return breaks.get(f"{line}", {})   # make sure the line is a string
