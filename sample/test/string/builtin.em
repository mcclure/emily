# String prototype methods

# Expect:
# a
# ⚧
# c
# 北

"a⚧c".each println

println: do: ^( "北京市".each ^!x( return x ) )
