# Test emily.functional module
# Expect:
# 1729.
# 3.
# 3.
# 7.
# 7.

p = package.emily.functional
c = p.combinator
u = p.util

# Test s, k, i
# Copypaste from ski/stars.em
{
    # FIXME: I need an import
    s = c.s; k = c.k; i = c.i
    counter = 0

    newline ^x = (       # Mimic Unlambda "r"
        println counter
        counter = 0
        x                # Act as identity
    )

    star ^x = (          # Mimic Unlambda ".*"
        counter = counter + 1
        x                # Act as identity
    )

    # "1729 stars" sample from Unlambda manual
    # Original author: David Madore <david.madore@ens.fr>
    (((s (k newline)) ((s ((s i) (k star))) (k i))) (((s ((s (k ((s i) (k (s ((s (k s)) k)))))) ((s ((s (k s)) k)) ((s ((s (k s)) k)) i)))) ((s (k ((s ((s (k s)) k)) ((s ((s (k s)) k)) i)))) (s ((s (k s)) k)))) (((s ((s (k s)) k)) i) ((s ((s (k s)) k)) ((s ((s (k s)) k)) i)))))
}

# FIXME: How on earth do you test v? I'm gonna skip it.

# Test apply
[c.a, u.apply].each ^a (a 3 println)

# Test compose, identity
[c.o, u.compose].each ^o (
    (o (u.identity): \
       o println: 3 .plus) 4
)