'''Common base for every class.'''


class BaseCommon:
    '''Common base part of all classes.'''
    def __init__(self, vim, logger, config):
        self.vim = vim
        self.logger = logger
        self.config = config

    def log(self, msg):
        '''Log a message with the class name as the key.'''
        self.logger.log(type(self).__name__, msg)

    def treat_the_linter(self):
        '''Let the linter be happy.'''


class Common(BaseCommon):
    '''Common part of all classes with convenient constructor.'''
    def __init__(self, common):
        super().__init__(common.vim, common.logger, common.config)
