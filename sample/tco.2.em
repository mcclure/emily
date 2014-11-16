# Test that tail call recursion works and does not infinitely grow the stack or anything.

set .prints 0

set .recurse ^ x {
	# Waste some space
	set .a (x .minus 1)
	set .b (x .minus 2)
	set .c (x .minus 3)
	set .d (x .minus 4)
	set .e (x .minus 5)

	(x .gt 10000).if ^(
		print "So far printed " prints " times" nl
		set .x 0
		set .prints (prints .plus 1)
	)

	(0 .gt x).tern ^( recurse (0 .minus (x .plus 1)) ) ^( recurse2 x )
}

set .recurse2 ^ x {
	recurse x
}

recurse 0
