# Test *setting* the parent field on scopes.
# FIXME: This really shouldn't be allowed.
# Expect:
# f
# s
# 4.
# 5.
# Back to normal
# f
# s
# 4.
# 5.

# Interesting trivia: without the inner scope,
# this will just screw everything up horribly, because private
{
    let .x 5
    set .parent println

    f
    s 4 x
}

println "Back to normal"

# Same as code above, but setting private's parent instead of global parent

let .x 5
private.set .parent println

f
s 4 x
