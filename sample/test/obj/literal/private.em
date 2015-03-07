# Test private within an object literal.
# Expect:
# 2.
# 3.
# <true>
# <null>
# <null>

context = 2

obj = [
    private.shadowed = 3
    shadowed = 4
    visible = 5
    private.hidden = 6
    println: context
    # println: hidden   # TODO
    # println: shadowed # TODO
    println: private.shadowed
]

println: obj.has .visible
println: obj.has .private
println: obj.has .hidden