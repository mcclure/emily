# Test boolean/logic operators

# Expected output: true
println (4 .lt 5)

# Expect output: true
println ( ( 4 .lt 5 ) .and (1 .lt 9) )

# Expect output: false
println ( () .and 4 )

# Expect output: true
println ( 5 .and 4 )