'''Common base for every class.'''

import logging


class BaseCommon:
    '''Common base part of all classes.'''
    def __init__(self, vim, config):
        self.vim = vim
        self.config = config
        self.logger = logging.getLogger(type(self).__name__)

    def treat_the_linter(self):
        '''Let the linter be happy.'''


class Common(BaseCommon):
    '''Common part of all classes with convenient constructor.'''
    def __init__(self, common):
        super().__init__(common.vim, common.config)
