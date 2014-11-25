# Test an unscoped group. Expected output: 4.0 [newline] 4.0

let .b 3

(
	let .b 4
	println b
)

println b