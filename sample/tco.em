# Test that tail call recursion works and does not infinitely grow the stack or anything.

let .prints 0

let .recurse ^ x {
	# Waste some space
	let .a (x .minus 1)
	let .b (x .minus 2)
	let .c (x .minus 3)
	let .d (x .minus 4)
	let .e (x .minus 5)

	(x .gt 10000).if ^(
		print "So far printed " x " times" nl
		set .x 0
	)

	recurse (x .plus 1)
}

recurse 0