# Demonstrate a curried closure.
# Expect:
# 7.
# 11.

set .a ^x y( println (x .plus y) )
print (a 3 4)
set .b (a 5)
print(b 6)
