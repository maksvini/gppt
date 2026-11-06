#!/usr/bin/env python3
"""Run the PTT daemon tied to the shell's lifetime.

The shell kills its children hard on exit and leaves them orphaned on a crash,
and either way the daemon would skip the unmute it does on SIGTERM. Asking the
kernel for SIGTERM when the parent dies covers the crash, so a stale daemon can
never keep Discord muted after the shell that owned it is gone.
"""
import ctypes
import os
import runpy
import signal
import sys

PR_SET_PDEATHSIG = 1

parent = os.getppid()
ctypes.CDLL(None, use_errno=True).prctl(PR_SET_PDEATHSIG, signal.SIGTERM)
# The parent may have died between fork and prctl, which raises no signal.
if os.getppid() != parent:
    sys.exit(0)

script = sys.argv[1]
sys.argv = sys.argv[1:]
runpy.run_path(script, run_name='__main__')
