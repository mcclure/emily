# Test loop construct. Expected output: numbers 10 through 1, descending.

set .a 10

loop ^(
	println a
	set .a (a .minus 1)
	a.gt 0
)