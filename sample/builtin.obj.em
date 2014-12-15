# Test object base class methods.
# Expect:
# 5.
# 3.
# 2.
# 1.

let .array [
    # FIXME: "current" is a really unpleasant way to do this.
    current.append 5
    current.append 3
    current.append 2
    current.append 1
]

array.each ^i (println i)