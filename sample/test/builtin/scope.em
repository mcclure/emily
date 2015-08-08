# Test all random library (builtinScope) functions that don't have their own tests

# Test sp, ln

# Expect: a b
print "a" sp "b" ln

# Test printsp

# Expect:
# a b   c
# d
printsp "a" "b" " " "c" ln "d" ln

# Test do

# Expect: 8.
do ^(println 8)

# Test nullfn, true

tern true nullfn ^{ println 9 }

# Test if, null

# Expect: 7.
if (3)    ^{println 7}
if (null) ^{println 6}

# Test while

# Expect:
# 3.
# 2.
# 1.
let .i 3
while ^(i.gt 0) ^{println i; set .i (i .minus 1)}

# Test and, or, xor

# Expect: <null>
println ( xor ^(or ^( and ^(true) ^(null) ) ^(true) ) ^(true) )

# Test math

# Expect: 2.
println: floor 2.718281828

# Test types

# Expect: <true> <null> <true> <null> <true> <null> <true> <null>
print (atom .atom)       sp (atom "atom")          sp \
      (string "3.14159") sp (string 3.14159)       sp \
      (number 3.14159)   sp (number "3.14159")     sp \
      (int 3)            sp (int 3.14159)          ln

# Test scope manipulation

# Expect: 3.

a = 3
println: scope.a

# Expect: 4.

scope.a = 4
println: a