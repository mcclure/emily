# Test object base class methods.
# Expect:
# Count: 4.
# 5.
# 3.
# 2.
# 1.

let .array [
]

array.append 5
array.append 3
array.append 2
array.append 1

print "Count: "  (array.count) ln
array.each ^i (println i)