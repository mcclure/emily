# Demonstrate equality on non-number values
# Expect:
# <true>
# <true>
# <null>
# <true>
# <null>
# <true>
# <null>
# <null>

println ( null .eq null )
println ( true .eq true )
println ( null .eq true )
println ( "ok" .eq "ok" )
println ( "ok" .eq "bad" )
println ( .ok  .eq .ok )
println ( .ok  .eq .bad )
println ( "ok" .eq .ok )
