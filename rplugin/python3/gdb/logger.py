'''.'''


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
        #'file': {
        #    'level': 'INFO',
        #    'formatter': 'standard',
        #    'class': 'logging.FileHandler',
        #    'filename': '/tmp/nvimgdb.log',
        #    #'mode': 'a',
        #},
    },
    'loggers': {
        '': {  # root logger
            'handlers': ['null'],
            'level': 'INFO',
            'propagate': False
        },
    }
}
