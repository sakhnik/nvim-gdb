"""Common base for every class."""

import logging
import pynvim


class BaseCommon:
    """Common base part of all classes."""

    def __init__(self, vim, config):
        """Construct to propagate context."""
        self.vim: pynvim.Nvim = vim
        self.config = config
        self.logger: logging.Logger = logging.getLogger(type(self).__name__)

    def treat_the_linter(self):
        """Let the linter be happy."""

    def treat_the_linter2(self):
        """Let the linter be happy 2."""


class Common(BaseCommon):
    """Common part of all classes with convenient constructor."""

    def __init__(self, common):
        """ctor."""
        super().__init__(common.vim, common.config)
