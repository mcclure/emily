# Test private within a package.
# Should change in lockstep with obj/literal/private
# Expect:
# (Inside)
# 4.
# 4.
# 7.
# <true> <true> <true>
# <null> <null>
# <true> <true> <true> <true>
# <null> <true> <true> <null>
# <null> <true> <null> <true>
# (Inner method)
# (Outside)
# 7.
# <true> <null> <null> <null>
# <null> <null> <null> <true>

pkg = project.inner.private

do: pkg.innerMethod

println: "(Outside)"

# Read back object member
println: pkg.shadowed

# By the way, this isn't a package, so it shouldn't have a private or a current.
print (has .let) sp (has .private) sp (has .current) sp (has .shadowed) ln

# Ensure privates from literal didn't leak out into object
print (pkg.has .println) sp (pkg.has .hidden) sp (pkg.has .private) sp (pkg.has .visible) ln
