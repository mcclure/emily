# Tests for the scientific notation float literals

# Expect: 0.
println 0e12
# Expect: 1.
println 1e-0
# Expect: 10.
println 1e+1

# Expect: <true>
println: 1E2 == 10E1
# Expect: <true>
println: 0.1E1 == 10E-1