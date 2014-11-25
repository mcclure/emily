# Test a scoped group. Expected output: 4.0 [newline] 3.0

let .b 3

{
	set .b 4
	println b
}

println b