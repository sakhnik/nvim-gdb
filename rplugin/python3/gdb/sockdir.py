'''.'''

import tempfile
from typing import Optional


class SockDir:
    '''Unique directory for the rendez-vous point.'''
    def __init__(self):
        self.sock_dir: Optional[tempfile.TemporaryDirectory] = tempfile.TemporaryDirectory(prefix='nvimgdb-sock')

    def cleanup(self):
        '''The destructor.'''
        if self.sock_dir:
            self.sock_dir.cleanup()
            self.sock_dir = None

    def get(self):
        '''The accessor.'''
        return self.sock_dir.name
