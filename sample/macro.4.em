# Test ternary macro and its quirks.
# Expect:
# 21.
# 4.

println: true ? 1 2 + null ? 10 20

# If you accidentally use C++ syntax, something bad happens.
# TODO: Colon and ? should work together
let .x ^a{a + 2}
println: true ? x 1 : 2
