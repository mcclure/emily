# Demonstrate a curried closure.
# Expect:
# 7.
# 11.

let .a ^x y ( x .plus y )
let .b  (a 5)

println (a 3 4)
println (b 6)
