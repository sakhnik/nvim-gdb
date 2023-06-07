#!/usr/bin/env python3

import sys
from proxy.pdb import Pdb

pdb = Pdb(sys.argv[1:])
sys.exit(pdb.run())
