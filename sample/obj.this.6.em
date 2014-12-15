# Test "this" inside a raw box definition
# Expect:
# <table>
# <table>
# 3.
# 3.

let .a [
    let .b ^{println 3}
    current.b
    this.b
]