# Test a scoped group. Expected output: 4.0 [newline] 3.0

let .b 3

{
	let .b 4
	print b
}

print "\n"
print b