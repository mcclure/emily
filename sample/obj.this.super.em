# Test "this" binding with method call
# Expect:
# 3.

let .a [
    let .b 1
    let .c ^{ this.set.b 2 }
]

let .e [
    let .parent a
    let .c ^{ # Overrides a.c
        this.set.b 3
        super.c null
    }
]

# Expected result: Resolves to e.c, which invokes a.c, which sets a.b to 2
e.c null

println( a.b )
