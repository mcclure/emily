#!/usr/bin/python

# This is a simple test harness script. It targets Emily files, extracts expected
# results from codes in the comments, and verifies the script runs as expected.
#
# Recognized codes:
#
#   #? fail
#       Emily interpreter should fail
#
#   #> SOMETHING
#       Expect "SOMETHING" as an output line (Note: First space consumed)
#
# Usage: ./develop/regression.py -a

import subprocess

