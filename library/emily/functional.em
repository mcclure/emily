# Functional programming basics

combinator = [
    o ^x y z = x: y z
    a ^x y = y x
    v ^ = v
    i ^x = x
    k ^ x y = x
    s ^ x y z = x z (y z)
]

util = [
    apply    = combinator.a
    identity = combinator.i
    compose  = combinator.o

    lazyMap ^f obj = obj.each ^x( x, )

    map ^f obj = [ obj.each ^x( x, ) ]
]