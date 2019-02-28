import os

class Logger:
    def __init__(self):
        fname = os.getenv('NVIMGDB_LOGFILE')
        self.f = None if not fname else open(fname, 'w')
        keys = os.getenv('NVIMGDB_LOGKEYS')
        self.keys = {} if not keys else set(keys.split(','))

    def log(self, key, msg):
        if self.f and key in self.keys:
            self.f.write('[{}] {}\n'.format(key, msg))
            self.f.flush()
