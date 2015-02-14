# Test a backslash line continuation.
# Expect:
# 4.
# 5.

println \
4

# Whitespace after backslash
println \    
5

# Version directive. A noop.
\version 0.1

# This is awful, but it's coincidentally allowed:
# Stray backslashes before version directive, whitespace after.
# Because version doesn't consume newline, 6 is NOT printed.
println \ \\ \version 0.1     
	6