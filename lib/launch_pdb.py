#!/usr/bin/env python3

import os
import sys
from proxy.pdb import Pdb

# The script can be launched as `python3 script.py`
args_to_skip = 0 if os.path.basename(__file__) == sys.argv[0] else 1
pdb = Pdb(sys.argv[args_to_skip:])
sys.exit(pdb.run())
