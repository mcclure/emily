# Test intersection of "has" with an incompletely applied let
# Expect:
# <null>
# <true>
# <null>

println (has .a)
let .a
println (has .a)
println a