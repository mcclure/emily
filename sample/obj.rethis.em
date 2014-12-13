# Test magic "rethis" function
# Expect:
# 2.
# 2.
# 3.
# 2.

let .obj1 [
    let .var1 2
]

let .obj2 [
    let .var1 3
    let .meth ^(println (current.var1) (this.var1))
]

# Test rethis on "new" closure
( rethis obj1 ^(println (current.var1) (this.var1)) ) null

# Test rethis on closure from dictionary
( rethis obj1 (obj2.meth) ) null
