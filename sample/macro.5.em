# Test assignment macro.
# Expect:
# 3.
# 4.
# 5.
# 6.
# 9.
# 7.

a = 3
b = []
b.x = 4
b a = 5
b (b.x) = 6

println a (b.x) (b 3) (b 4)

# This is pretty awkward: the "nonlocal" tag is the inverse of the "let" tag.
# It means ultimately the assignment is based on set rather than let.
{
    nonlocal a = 7 # So this falls through,
    a = 8          # This creates a new a binding in this scope,
    nonlocal a = 9 # This catches on the a binding in this scope.
    println a
}
println a
