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

import sys
import subprocess
import optparse
import re

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

expectp = re.compile(r'# Expect(\s*failure)?(\:?)', re.I)
linep = re.compile(r'# ?(.+)$', re.S)

failures = 0

for filename in files:
    expectfail = False
    scanning = False
    outlines = ''
    with open(filename) as f:
        for line in f.readlines():
            expect = expectp.match(line)
            if expect:
                expectfail = bool(expect.group(1))
                scanning = bool(expect.group(2))
            else:
                outline = linep.match(line)
                if scanning and outline:
                    outlines += outline.group(1)
                else:
                    scanning = False

    print "Running %s..." % (filename)
    proc = subprocess.Popen(stdcall+[filename], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    result = proc.wait()
    outstr, errstr = proc.communicate()

    if bool(result) ^ bool(expectfail):
        print "\tFAIL: Process failure " + ("expected" if expectfail else "not expected") + " but " + ("seen" if result else "not seen")
        failures += 1
    elif outstr.rstrip() != outlines.rstrip():
        print "X '%s' '%s'"%(outstr.rstrip(), outlines.rstrip())
        print "\tFAIL: Output differs"
        failures += 1

print "\n%d tests failed of %d" % (failures, len(files))

sys.exit(0 if failures == 0 else 1)