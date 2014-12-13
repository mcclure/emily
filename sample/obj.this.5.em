# Test "this" binding with method call
# Expect:
# <table>
# <table>
# 5
# 6

let .a [
    let .b ^ curren thi { println current this }
    let .c ^ current this { println current this }
]

a.b 3 4
a.c 5 6