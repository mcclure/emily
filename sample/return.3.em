# Test that non-explicit closures don't get their own returns.
# Expect:
# 5.

a ^b = (
    b > 5 ? return 5 : null
    return b
)

println: a 10