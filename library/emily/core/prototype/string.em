parent = directory.primitive

# Given a binary function, embed it on the current object as a method
private.setMethodFrom ^key method = \
    internal.setPropertyKey current key method

setMethodFrom .each: ^str fn {
    iter = internal.string.iterUtf8 str
    loop: ^(iter fn)
}
