"""
ANSI control sequence matcher.
"""

import re


CSEQ_STR = rb'\[[^a-zA-Z]*[a-zA-Z]'
CSEQ = re.compile(CSEQ_STR)
