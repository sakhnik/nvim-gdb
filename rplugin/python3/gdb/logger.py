"""."""

import os


LOGGING_CONFIG = {
    'version': 1,
    'disable_existing_loggers': True,
    'formatters': {
        'standard': {
            'format': '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
        },
    },
    'handlers': {
        'null': {
            'class': 'logging.NullHandler',
        },
        'file': {
            'level': 'DEBUG',
            'formatter': 'standard',
            'class': 'logging.FileHandler',
            'filename': 'nvimgdb.log',
            #'mode': 'a',
        },
    },
    'loggers': {
        '': {  # root logger
            'handlers': ['file' if os.environ.get('CI') else 'null'],
            'level': 'DEBUG',
            'propagate': False
        },
    }
}
