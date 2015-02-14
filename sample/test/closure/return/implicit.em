# Test that non-explicit closures don't get their own returns.
# Expect:
# 5.
# 20.

# Return inside ?: implicit closure
a ^b = (
    b > 5 ? return 5 : null
    return b
)

# Return inside horrible ^! construct
c ^d = {
    ret = ^! x ( return x )
    ret 20
    return d
}

println: a 10
println: c 21