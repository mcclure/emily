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
import optparse

stdfile = "sample/regression.txt"

help  = "%prog -a\n"
help += "\n"
help += "Accepted arguments:\n"
help += "-f [filename.em]  # Check single file\n"
help += "-t [filename.txt] # Check all paths listed in file\n"
help += "-a # Check all paths listed in standard " + stdfile

parser = optparse.OptionParser(usage=help)
for a in ["a"]: # Single letter args, flags
    parser.add_option("-"+a, action="store_true")
for a in ["f", "t"]: # Long args with arguments
    parser.add_option("-"+a, action="append")

(options, cmds) = parser.parse_args()
def flag(a):
    x = getattr(options, a)
    if x:
        return x
    return []

if cmds:
    parser.error("Stray commands: %s" % cmds)

indices = []
files = []

if flag("a"):
    indices += [stdfile]

indices += flag("t")

for filename in indices:
    with open(filename) as f:
        for line in f.readlines():
            line = line.rstrip()
            if line:
                files += [line]

files += flag("f")

if not files:
    parser.error("No files specified")

stdcall = ["./package/emily"]

for filename in files:
    print "Running %s..." % (filename)
    subprocess.call(stdcall+[filename])