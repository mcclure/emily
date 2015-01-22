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
#   # SOMETHING
#       Expect "SOMETHING\nSOMETHING" as program output. (Notes: First space of
#       line always consumed; trailing whitespace of output always disregarded.)
#
# Usage: ./develop/regression.py -a
# Tested with Python 2.6.1

import sys
import os
import subprocess
import optparse
import re

def projectRelative( filename ):
    print (filename)
    return os.path.normpath(os.path.join(prjroot, filename))

prjroot = os.path.join( os.path.dirname(__file__), ".." )
stddir  = "sample"
stdfile = "sample/regression.txt"
badfile = "sample/regression-known-bad.txt"

help  = "%prog -a\n"
help += "\n"
help += "Accepted arguments:\n"
help += "-f [filename.em]  # Check single file\n"
help += "-t [filename.txt] # Check all paths listed in file\n"
help += "-r [path]         # Set the project root\n"
help += "-a          # Check all paths listed in standard " + stdfile + "\n"
help += "-A          # Also check all paths listed in std " + badfile + "\n"
help += "-v          # Print all output\n"
help += "-s          # Use system emily interpreter\n"
help += "--untested  # Check repo hygiene-- list all tests in sample/ not tested"

parser = optparse.OptionParser(usage=help)
for a in ["a", "A", "v", "s", "-untested"]: # Single letter args, flags
    parser.add_option("-"+a, action="store_true")
for a in ["f", "t", "r"]: # Long args with arguments
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

if flag("r"):
    prjroot = flag("r")[0]

if flag("a") or flag("A"):
    indices += [projectRelative(stdfile)]

if flag("A"):
    indices += [projectRelative(badfile)]

indices += flag("t")

indexcommentp = re.compile(r'#.+$', re.S) # Allow comments in .txt file
for filename in indices:
    with open(filename) as f:
        for line in f.readlines():
            line = indexcommentp.sub("", line)
            line = line.rstrip()
            if line:
                files += [projectRelative(line)]

files += flag("f")

if not files:
    parser.error("No files specified")

if flag("untested"):
    for filename in os.listdir(projectRelative(stddir)):
        path = os.path.join(projectRelative(stddir), filename)
        if not (path.endswith(".txt") or path in files):
            print path
    sys.exit(0)

stdcall = [projectRelative("package/emily")]
if flag("s"):
    stdcall = ["emily"]

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
    try:
        proc = subprocess.Popen(stdcall+[filename], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as e:
        print "\nCATASTROPHIC FAILURE: Couldn't find emily?:"
        print e
        print "Make sure you ran a plain `make` first."
        sys.exit(1)
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
            print "\n"+pretag("STDERR",errstr)
        failures += 1
    elif outstr != outlines:
        print "\tFAIL:   Output differs"
        print "\n%s\n\n%s" % ( pretag("EXPECT", outlines), pretag("STDOUT",outstr) )
        failures += 1
    elif flag("v"):
        if outstr:
            print pretag("STDOUT", outstr)
        if outstr and errstr:
            print
        if errstr:
            print pretag("STDERR",errstr)

print "\n%d tests failed of %d" % (failures, len(files))

sys.exit(0 if failures == 0 else 1)
