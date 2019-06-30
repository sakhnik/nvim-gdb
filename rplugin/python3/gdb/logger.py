'''.'''

import os


class Logger:
    '''The logger configurable with environment variables.'''
    def __init__(self):
        fname = os.getenv('NVIMGDB_LOGFILE')
        self.fout = None if not fname else open(fname, 'w')
        keys = os.getenv('NVIMGDB_LOGKEYS')
        self.keys = {} if not keys else set(keys.split(','))

    def log(self, key, msg):
        '''Log a message identified by the key.'''
        if self.fout and key in self.keys:
            self.fout.write(f'[{key}] {msg}\n')
            self.fout.flush()

    def dummy(self):
        '''Do nothing.'''
