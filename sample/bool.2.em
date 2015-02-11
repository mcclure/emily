# Non-simple tests of boolean/logic operators
# Expect:
# <true>
# <true>
# <null>
# 4.
# <null>
# 3.
# 6.
# 8.

# Expected output: true
println: 4 < 5

# Expect output: true
println: 4 < 5 && 1 < 9

# Expect output: false
println: () && 4

# Expect output: true (4)
println: 5 && 4

# Expect output: false
println ( !(!5 || 4) )

# Test short circuit:

println 3 || println 5
println 6 && println 8
