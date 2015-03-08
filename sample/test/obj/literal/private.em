# Test private within an object literal.
# Expect:
# 7.
# 4.
# 4.
# 7.
# 3.
# <true>
# <null>
# <null>
# <null>

shadowed = 2

obj = [
    # Test nonlocal set works as expected, and can be inherited into private (this is weird and I don't like it)
    private.set.shadowed 7

    # Test object member assignment
    shadowed = 3

    # Test scope fallthrough
    println: shadowed

    # Test assigning private variable
    private.shadowed = 4

    # Test assigning object variable with unique name, for has test
    visible = 5

    # Test assigning private variable with unique name, for has test
    private.hidden = 6

    # Test we see private shadowed and not outer shadowed
    println: shadowed

    # Test we can read both private variables and enclosing-scope variables by looking in private
    private.println: private.shadowed
]

# Read back global scope
println: shadowed

# Read back object member
println: obj.shadowed

# Ensure no leakage of private things
println: obj.has .visible
println: obj.has .private
println: obj.has .hidden
println: has .hidden