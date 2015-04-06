# Test any random library (builtinScope) functions that don't have their own tests
# Expect:
# a b
# 8.
# 7.
# 3.
# 2.
# 1.

# Test sp, ln
print "a" sp "b" ln

# Test do
do ^(println 8)

# Test nullfn, true
tern true nullfn ^{ println 9 }

# Test if, null
if (3)    ^{println 7}
if (null) ^{println 6}

# Test while
let .i 3
while ^(i.gt 0) ^{println i; set .i (i .minus 1)}