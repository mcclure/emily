# Here for package/private test to include
# NOT DIRECTLY EXECUTED BY REGRESSION TESTS
# Modeled on obj/literal/private, should change in lockstep

println: "(Inside)"

# Plain assignment assigns to package+scope; private assignment assigns to private+scope.
# In other words, whichever of these two assignments occur second for a single variable
# is the one which survives in the current scope. Test these rules:

shadowed = 14
{
    shadowed = 19;        # Overwrites locally but does not last
    private.shadowed = 17 # Overwrites nonlocally, lasts
    print shadowed   sp (private.shadowed)   sp (current.shadowed)   ln
}

private.unshadowed = 4
unshadowed = 7
{
    unshadowed = 9;    # Overwrites locally but does not last
    print unshadowed sp (private.unshadowed) sp (current.unshadowed) ln
}

# Test private, current and scope have the expected values following the above.
print shadowed   sp (private.shadowed)   sp (current.shadowed)   ln
print unshadowed sp (private.unshadowed) sp (current.unshadowed) ln

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