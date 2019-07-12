'''Read backend configuration.'''

import os


BACKEND_NAMES = ['XXX']
with open(os.path.join(os.path.dirname(__file__),
                       'backends.txt'), 'r') as fback:
    BACKEND_NAMES = [s.strip() for s in fback.readlines()]
