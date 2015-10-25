# Test private within a package.
# Should change in lockstep with obj/literal/private
# Expect:
# (Inside)
# 19. 17. 14.
# 9. 4. 7.
# 17. 17. 14.
# 7. 4. 7.
# <true> <true> <true>
# <null> <null>
# <true> <true> <true> <true>
# <null> <true> <true> <null>
# <null> <true> <null> <true>
# (Inner method)
# (Outside)
# 14. 7.
# <true> <null> <null> <null>
# <null> <null> <null> <true>

pkg = project.inner.private

do: pkg.innerMethod

println: "(Outside)"

# Read back object member
print (pkg.shadowed) sp (pkg.unshadowed) ln

# By the way, this isn't a package, so it shouldn't have a private or a current.
print (has .let) sp (has .private) sp (has .current) sp (has .shadowed) ln

# Ensure privates from literal didn't leak out into object
print (pkg.has .println) sp (pkg.has .hidden) sp (pkg.has .private) sp (pkg.has .visible) ln
