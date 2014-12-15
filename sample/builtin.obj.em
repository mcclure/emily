# Test object base class methods.
# Expect:
# 5.
# 3.
# 2.
# 1.

let .array [
    this.append 5
    this.append 3
    this.append 2
    this.append 1
]

array.each ^i (println i)