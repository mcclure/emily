# Test variable shadowing for an unscoped closure. Expected output: 4.0 [newline] 3.0

let .b 3

^b(
	println b
) 4

println b