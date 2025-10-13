#!/usr/bin/env python3

import shutil
import os
import sys
from pathlib import Path


NFS_STATS = Path("/proc/net/rpc/nfsd")
STATE_FILE = Path("/var/run/nfsd_stats.last")

IDLE = "idle"
ACTIVE = 0


if not NFS_STATS.exists():
    sys.exit(ACTIVE)
    

if STATE_FILE.exists():
    if NFS_STATS.open().read() == STATE_FILE.open().read():
        sys.exit(IDLE)

shutil.copyfile(NFS_STATS, STATE_FILE)
sys.exit(ACTIVE)
