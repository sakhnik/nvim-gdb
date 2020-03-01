'''.'''

import json
from gdb.common import Common


class Breakpoint(Common):
    '''Handle breakpoint signs.'''
    def __init__(self, common, proxy, backend):
        super().__init__(common)
        self.proxy = proxy
        self.backend = backend
        self.breaks = {}    # {file -> {line -> [id]}}
        self.max_sign_id = 0

        # Function to transform source file name before querying
        locate_source_file = getattr(self.backend, "LocateSourceFile", None)
        self.locate_source_file = locate_source_file \
                if callable(locate_source_file) else lambda a, _: a

    def clear_signs(self):
        '''Clear all breakpoint signs.'''
        for i in range(5000, self.max_sign_id + 1):
            self.vim.call('sign_unplace', 'NvimGdb', {'id': i})
        self.max_sign_id = 0

    def _set_signs(self, buf):
        if buf != -1:
            sign_id = 5000 - 1
            # Breakpoints need full path to the buffer (at least in lldb)
            bpath = self.vim.call("expand", f'#{buf}:p')

            def _get_sign_name(count):
                max_count = len(self.config.get('sign_breakpoint'))
                idx = count if count < max_count else max_count - 1
                return f"GdbBreakpoint{idx}"

            for line, ids in self.breaks.get(bpath, {}).items():
                sign_id += 1
                sign_name = _get_sign_name(len(ids))
                self.vim.call('sign_place', sign_id, 'NvimGdb', sign_name, buf,
                        {'lnum': line, 'priority': 10})
            self.max_sign_id = sign_id

    def query(self, buf_num, fname):
        '''Query actual breakpoints for the given file.'''
        # Transform the source file path if necessary for the backend
        self.logger.info(f"Query breakpoints for {fname}")
        fname_sym = self.locate_source_file(fname, self.proxy)
        if fname != fname_sym:
            self.logger.info(f"Map file path {fname} to {fname_sym}")
        self.breaks[fname] = {}
        resp = self.proxy.query(f"info-breakpoints {fname_sym}\n")
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
