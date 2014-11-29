#!/usr/bin/python

# This is a simple test harness script. It targets Emily files, extracts expected
# results from codes in the comments, and verifies the script runs as expected.
#
# Recognized comment codes:
#
#   # Expect failure
#       Emily interpreter should fail
#
#   # Expect:
#   # SOMETHING
#       Expect "SOMETHING" as an output line (Note: First space always consumed)
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
help += "-a # Check all paths listed in standard " + stdfile + "\n"
help += "-v # Print all output"

parser = optparse.OptionParser(usage=help)
for a in ["a","v"]: # Single letter args, flags
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
startp = re.compile(r'^', re.MULTILINE)

def pretag(tag, str):
    tag = "\t%s: " % (tag)
    return startp.sub(tag, str)

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

    result = bool(result)
    expectfail = bool(expectfail)
    outlines = outlines.rstrip()
    outstr = outstr.rstrip()
    errstr = errstr.rstrip()

    if result ^ expectfail:
        print "\tFAIL:   Process failure " + ("expected" if expectfail else "not expected") + " but " + ("seen" if result else "not seen")
        if errstr:
            print pretag("STDERR",errstr)
        failures += 1
    elif outstr != outlines:
        print "\tFAIL:   Output differs"
        print "\n%s\n\n%s" % ( pretag("EXPECT", outlines), pretag("STDOUT",outstr) )
        failures += 1
    elif flag("v"):
        print "\n".join( ([pretag("STDOUT", outstr)] if outstr else []) + ([pretag("STDERR",errstr)] if errstr else []) )

print "\n%d tests failed of %d" % (failures, len(files))

sys.exit(0 if failures == 0 else 1)