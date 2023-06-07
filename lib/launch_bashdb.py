#!/usr/bin/env python3

import sys
from proxy.bashdb import BashDb

proxy = BashDb(sys.argv[1:])
exitcode = proxy.run()
sys.exit(exitcode)
