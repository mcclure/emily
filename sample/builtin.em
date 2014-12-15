# Test any random library (builtinScope) functions that don't have their own tests
# Expect:
# 8.
# 7.
# 3.
# 2.
# 1.

# Test do
do ^(println 8)

# Test nullfn
tern null ^{ println 9 } nullfn

# Test while/if
if (3)    ^{println 7}
if (null) ^{println 6}

let .i 3
while ^(i.gt 0) ^{println i; set .i (i .minus 1)}