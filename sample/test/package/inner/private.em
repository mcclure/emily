# Here for package/private test to include
# NOT DIRECTLY EXECUTED BY REGRESSION TESTS
# Modeled on obj/literal/private, should change in lockstep

println: "(Inside)"

# Test assigning private variable
private.shadowed = 4

# Test nonlocal set works as expected-- should fall through to outer scope
shadowed = 7

# Test private scope shadows current scope (is this confusing?)
println: shadowed

# Test private may be queried directly
println: private.shadowed

# Test package assignment did work
println: current.shadowed

# Test assigning package variable with unique name, for has test
visible = 5

# Test assigning private variable with unique name, for has test
private.hidden = 6

# Test has doesn't get confused around the "invisible" box scope
print (has .let) sp (has .private) sp (has .current) ln

# Test a couple weird places private could (but shouldn't) leak
print (private.has .private) sp (current.has .private) ln

# Test we see both private and global variables in basic scope, but don't see global in private scope
print (has .println)         sp (has .shadowed)         sp (has .hidden)            sp (has .visible)         ln \
      (private.has .println) sp (private.has .shadowed) sp (private.has .hidden)    sp (private.has .visible) ln \
      (current.has .println) sp (current.has .shadowed) sp (current.has .hidden)    sp (current.has .visible) ln

innerMethod ^ = println: "(Inner method)"