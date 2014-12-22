# Verify method invocation has same behavior with this regardless of direct/indirect invoke
# Expect:
# 1.
# 1.

let .obj1 [
    let .var1 1
    let .meth ^{ println(this.var1) }
]

obj1.meth null
do (obj1.meth)