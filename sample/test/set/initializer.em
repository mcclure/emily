# Test the group initializer feature.

x = [ a = 1; b = 2 ]

# Expect: 1.
println: x.a

# Expect: 3.
println { x | a = 3; a }

# Expect: 1.
println: x.a

# Expect: 5.
println ( x | a = 5; a )

# Expect: 5.
println: x.a

# Expect: 7.
println: [ x | a = 7 ].a

# Expect: 7.
println: x.a
