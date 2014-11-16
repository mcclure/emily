# Test that a "real" program can run. Prints the finonachi numbers.

set .a 0
set .b 1

loop ^{
	println b

	set .c (a .plus b)
	set .a b
	set .b c

	true
}
