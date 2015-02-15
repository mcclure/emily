# Demonstrate equality on non-number values
# Expect:
# <true>
# <true>
# <null>
# <null>
# <true>
# <null>
# <true>
# <null>
# <null>
# <null>
# <true>
# <null>
# <null>

println ( null .eq null )
println ( true .eq true )
println ( null .eq true )
println ( true .eq null )
println ( "ok" .eq "ok" )
println ( "ok" .eq "bad" )
println ( .ok  .eq .ok )
println ( .ok  .eq .bad )
println ( "ok" .eq .ok )
println ( 2 .eq 3 )
println ( 3 .eq 3 )
println ( true .eq 3 )
println ( null .eq .null ) # Notice the dot