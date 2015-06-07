parent = directory.primitive

# Given a binary function, embed it on the current object as a method
private.setMethodFrom ^key method = \
    internal.setPropertyKey current key method

setMethodFrom .plus:   internal.double.add
setMethodFrom .minus:  internal.double.subtract
setMethodFrom .times:  internal.double.multiply
setMethodFrom .divide: internal.double.divide
setMethodFrom .mod:    internal.double.modulus
setMethodFrom .lt:     internal.double.lessThan
setMethodFrom .lte:    internal.double.lessThanEqual
setMethodFrom .gt:     internal.double.greaterThan
setMethodFrom .gte:    internal.double.greaterThanEqual

# FIXME: Saying 0 .minus 1 at this point doesn't seem to work. Why not?
setMethodFrom .negate: internal.double.multiply: internal.double.subtract 0 1