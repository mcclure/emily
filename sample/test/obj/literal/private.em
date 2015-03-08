# Test private within an object literal.
# Expect:
# 2.
# 4.
# 2.
# 3.
# <true>
# <null>
# <null>

shadowed = 2

obj = [
    shadowed = 3
    println: shadowed
    private.shadowed = 4
    visible = 5
    private.hidden = 6
    println: shadowed
    # println: private.shadowed
]

println: shadowed
println: obj.shadowed
println: obj.has .visible
println: obj.has .private
println: obj.has .hidden